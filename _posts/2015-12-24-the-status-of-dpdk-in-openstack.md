---
layout: post
title: "The status of DPDK in Openstack"
description: ""
category:
tags: [dpdk,openstack]
---

OVS
===

ovs里面增加对dpdk支持的patch set是：

```shell
$ git log df1e5a3~1..8617aff --oneline --reverse
df1e5a3 netdev: Extend rx_recv to pass multiple packets.
40d26f0 netdev: Send ofpbuf directly to netdev.
b284085 dpif-netdev: Add ref-counting for port.
e4cfed3 dpif-netdev: Add poll-mode-device thread.
f779174 netdev: Rename netdev_rx to netdev_rxq
55c955b netdev: Add support multiqueue recv.
20ebd77 ofpbuf: Add OFPBUF_DPDK type.
275eebb utils: Introduce xsleep for RCU quiescent state
8a9562d dpif-netdev: Add DPDK netdev.
8617aff netdev-dpdk: Use multiple core for dpdk IO.
```

目前支持dpdk的OVS版本是：

```shell
$ git tag -l --contains 8a9562d
v2.3
v2.3.1
v2.3.2
v2.4.0
```

OVS中对DPDK的使用在INSTALL.DPDK.md中有详细介绍，与ovs普通使用方法不同的地方在于：

- 编译支持
  - 编译dpdk target
  - 编译ovs的时候指定dpdk library位置
- 启动支持
  - 配置系统的hugepage支持，因为dpdk需要使用hugepage, hugepage size必须是1G
  - 利用dpdk提供的NIC bind脚本进行网卡的unbind-bind操作，使网卡bind到UIO/VFIO
    的驱动上
  - ovs-vswitchd启动的时候需要指定"-dpdk"参数
  - ovs-vsctl增加bridge的时候"datapath_type=netdev", 添加bridge port的时候"type=dpdk"


devstack
=======

devstack是一个用来部署openstack的项目, 它支持plugin的形式，因此不包含在devstack
里面的需要额外部署的项目可以在项目里面另外包含一个"devstack"的目录, 并按照devstack
plugin要求的方式组织. 这样的plugin可以在devstack的local.conf中以"enable_plugin"
的方式添加. (e.g):

```ini
enable_plugin networking-ovs-dpdk https://github.com/openstack/networking-ovs-dpdk master
```



networking-ovs-dpdk & neutron
=============================

在openstack环境中, neutron以ml2 plugin的方式将ovs集成进来.
neutron如果要通过vhost-user来使用支持dpdk的ovs(称为ovs-dpdk), 它就需要从ovs-db
里面找到iface_type为"dpdkvhostuser"的VIF, 并且获得"vhu" socket 路径.

起初neutron是不支持vhost-user使用ovs-dpdk的，因此产生了这个单独的项目networking-ovs-dpdk.

前面说过的devstack可以支持plugin的方式添加额外部署项目, networking-ovs-dpdk就是作为
这样一个devstack的plugin项目, 在devstack的local.conf里面配置networking-ovs-dpdk
的信息。配置好以后，在devstack执行stack.sh进行部署的过程中:

- 执行networking-ovs-dpdk中配置环境的脚本，包括hugepage配置，NIC binding等
- 将ovs-dpdk的mechanism-driver以plugin的形式安装到neutron的neutron.ml2.mechanism_drivers这个
  namespace里，neutron会借助stevedore这个项目动态加载它.
- devstack根据neutron中配置的Q_PLUGIN来启动networking-ovs-dpdk中的ovs-dpdk的agent.



而neutron在近期加入了对ovs-dpdk的支持, patch如下:

```shell
commit 34d4d46c40b5204ffaf8c8a3e2464a19f9d8b2cd
Author: Terry Wilson <twilson@redhat.com>
Date:   Thu Oct 15 18:50:40 2015 -0500

    Add vhost-user support via ovs capabilities/datapath_type
    
    Adds the ovs 'config' property which returns the contents of the
    single row of the Open_vSwitch table. This gives access to certain
    OVS capabilities such as datapath_types and iface_types.
    
    Using this information in concert with the datapath_type config
    option, vif details are calculated by the OVS mech driver. If
    datapath_type == 'netdev' and OVS on the agent host is capable of
    supporting dpdkvhostuser, then it is used.
    
    Authored-By: Terry Wilson <twilson@redhat.com>
    Co-Authored-By: Sean Mooney <sean.k.mooney@intel.com>
    
    Closes-Bug: #1506127
    Change-Id: I5047f1d1276e2f52ff02a0cba136e222779d059c



$ git tag -l --contains 34d4d46c40b5204ffaf8c8a3e2464a19f9d8b2cd
8.0.0.0b1
```

这个patch在原来ovs的mechanism_driver和agent中增加了对dpdk的支持, 有了这个patch
以后可以通过neutron配置文件中ovs section配置"datapath_type"和"vhostuser_socket_dir"
使vhost-user使用dpdk为backend. (e.g):

```ini
[OVS]
datapath_type=netdev
vhostuser_socket_dir=/var/run/openvswitch
```


因为neutron中ovs的mechanism_driver和agent支持了ovs-dpdk, 所以原来存在于
networking-ovs-dpdk项目中以plugin方式加入到neutron的为ovs-dpdk服务的agent
和driver就被移除掉了. networking-ovs-dpdk中patch如下:

```shell
commit d2a6648293183bdc347c1be69b3ddbb57ba259d5
Author: Sean Mooney <sean.k.mooney@intel.com>
Date:   Thu Oct 1 20:26:35 2015 +0100

    removes forked ovs-dpdk neutron agent
    
    - This change removes the modifed ovs neutron
      openvswitch agent and it deployment code.
    - This change updates the sample local.conf files
      to configure the standard neutron openvswitch
      agent to manage ovs-dpdk
    
    Closes-Bug: #1501872
    
    Change-Id: Ic97c2f6d5c1c709faa70471b65e20abeb10f97b7

commit 224e4e166b02c2a1f49088debda499f6270c2a29
Author: Sean Mooney <sean.k.mooney@intel.com>
Date:   Thu Nov 19 19:44:24 2015 +0000

    remove ovsdpdk ml2 driver
    
    - This change removes the ovsdpdk ml2 driver and
      unit test code.
    
    - This change removes the deployment code specific
      to the ovsdpdk ml2 driver.
    
    - The devstack plugin has been updated to leaverage
      the in tree vhost-user support and modify
      the appropriate neutron configuration files.
    
    Change-Id: I1bc1cacec0d913f183783d08207f4335417cdec4
    Depends-On: I5047f1d1276e2f52ff02a0cba136e222779d059c
    Related-Bug: #1506127
```

Conclusion
==========

在使用devstack部署openstack的过程中, 将networking-ovs-dpdk以plugin的形式加入到
devstack中, 可以在openstack中使neutron支持ovs-dpdk. 

相应地其它工具部署openstack只需要将networking-ovs-dpdk项目中用于配置ovs-dpdk
环境的shell脚本集成进去就可以完成.
