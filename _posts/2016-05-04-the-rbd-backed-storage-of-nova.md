---
layout: post
title: "The rbd-backed storage of nova"
description: ""
category: Virtualization
tags: []
---

RBD LAYERING
============
<http://docs.ceph.com/docs/master/dev/rbd-layering/>
顾名思义，比如ceph里有一个base image，我们要clone到一个新的instance里，做法
分两步:

* 先给这个base image创建一个快照

* 对这个快照进行clone

快照在clone之前要设成protect状态

如果这个快照被clone了，那么在child没有被删除或者没有进行flatten操作之前,
这个快照的protect状态是取消不掉的，因此它不会被删除。只有它的children都
被删除或flatten以后(也即不再被依赖)，它才可以被删除。

rbd-layering 的实现中，并没有track每一个object在clone中是否存在，而是读到不存在
的object的时候就去parent那里找. 对于写操作，首先要检查object是否存在，不存在的
话要先从parent那里读出来再做写操作. 当然从parent那里读出再写操作，如果多个同时
进行肯定会有race，所以读出再写操作，是要原子进行的。

未来优化的方向：

* 目前读出是对整个object, 优化要更加细化操作粒度.
* 通过bitmap来避免每次检查object的存在.

Clone
====

在I版本之前，对于rbd-backed ephemeral disk, nova会把image从glance中下载到本地,
然后再重新上传到nova的rbd中. 如果glance的后端也是ceph, 而且glance已经把这个image
存到rbd里面，那就变成了从rbd下载到本地再上传到rbd,显得很多余，而且copy了很多
数据。 如果用rbd-layering, 直接在rbd中对image做snapshot, 然后clone这个snapshot,
就不会产生data copy. 这就是这个COW rbd-backed BP的想法( <https://blueprints.launchpad.net/nova/+spec/rbd-clone-image-handler>).

在I版本发布之前， 这个BP已经被merge了(<https://review.openstack.org/#/c/59149/>),
但是由于glance API相关的bug(<https://bugs.launchpad.net/nova/+bug/1291014>), 
在I版本发布之前被revert掉了，后来在J版本中又重新搞了一遍(<https://review.openstack.org/#/c/94295/>).
实现很简单，就是直接调用了rbd的接口,帖个代码:

```python
    import rbd

    def clone(self, image_location, dest_name):
        _fsid, pool, image, snapshot = self.parse_url(
                image_location['url'])
        LOG.debug('cloning %(pool)s/%(img)s@%(snap)s' %
                  dict(pool=pool, img=image, snap=snapshot))
        with RADOSClient(self, str(pool)) as src_client:
            with RADOSClient(self) as dest_client:
                # pylint: disable E1101
                rbd.RBD().clone(src_client.ioctx,
                                     image.encode('utf-8'),
                                     snapshot.encode('utf-8'),
                                     dest_client.ioctx,
                                     dest_name,
                                     features=rbd.RBD_FEATURE_LAYERING)
```

Snapshot
========

snapshot在M版本之前也存在上面的相似的问题，做snapshot的时候总是从rbd里面把nova
disk copy到本地, 再上传到glance的rbd-backend. M版本中实现的这个BP(<https://blueprints.launchpad.net/nova/+spec/rbd-instance-snapshots>)
也是为了不copy data到本地，直接在rbd里面完成snapshot.

基本步骤是:

* 在ceph pool中给nova ephemeral disk 创建一个RBD snapshot.
* 将上面创建的snapshot clone到glance的RBD pool中。
* 对这个clone进行deep-flatten操作, 去除这个clone对parent snapshot的依赖.
* 去除依赖后，删掉这个parent snapshot.
* 把flatten过的这个clone的location更新到glance中.

帖nova的代码来对应上面的步骤:

```python
   def direct_snapshot(self, context, snapshot_name, image_format,
                        image_id, base_image_id):
        """Creates an RBD snapshot directly.
        """
        fsid = self.driver.get_fsid()
        # NOTE(nic): Nova has zero comprehension of how Glance's image store
        # is configured, but we can infer what storage pool Glance is using
        # by looking at the parent image.  If using authx, write access should
        # be enabled on that pool for the Nova user
        parent_pool = self._get_parent_pool(context, base_image_id, fsid)

        # Snapshot the disk and clone it into Glance's storage pool.  librbd
        # requires that snapshots be set to "protected" in order to clone them
        self.driver.create_snap(self.rbd_name, snapshot_name, protect=True)
        location = {'url': 'rbd://%(fsid)s/%(pool)s/%(image)s/%(snap)s' %
                           dict(fsid=fsid,
                                pool=self.pool,
                                image=self.rbd_name,
                                snap=snapshot_name)}
        try:
            self.driver.clone(location, image_id, dest_pool=parent_pool)
            # Flatten the image, which detaches it from the source snapshot
            self.driver.flatten(image_id, pool=parent_pool)
        finally:
            # all done with the source snapshot, clean it up
            self.cleanup_direct_snapshot(location)

        # Glance makes a protected snapshot called 'snap' on uploaded
        # images and hands it out, so we'll do that too.  The name of
        # the snapshot doesn't really matter, this just uses what the
        # glance-store rbd backend sets (which is not configurable).
        self.driver.create_snap(image_id, 'snap', pool=parent_pool,
                                protect=True)
        return ('rbd://%(fsid)s/%(pool)s/%(image)s/snap' %
                dict(fsid=fsid, pool=parent_pool, image=image_id))
```
