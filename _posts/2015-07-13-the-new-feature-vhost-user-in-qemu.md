---
layout: post
title: "The new feature vhost-user in QEMU"
description: "Vhost-user applied to snabbswitch ethernet switch"
category: virtualization
tags: [kvm, qemu, virtio]
---
{% include JB/setup %}

The QEMU/KVM guest can access external network via virtio-net. QEMU emulated a
PCI device via virtio_pci, servers as the transport mechanism that implements
the Virtio ring. Virtio drivers lies on top of it to set up virtqueues, that
will be 'kicked' whenever buffers with new data are placed in them.  Virtio-net
is a network implementation on virtio. Guest running virtio-net will share a
number of virtqueues with QEMU process.  So, QEMU should process the network
traffic before it can be processed further by the network stack of host.

Then the vhost can **accelerate** the above process by **directly pass guest
network traffic to TUN device directly from the kernel side**. In this model,
QEMU will pass direct control of a virtqueue to a kernel driver.

While vhost-user want to event skip the kernel part and process the network
traffic in userspace directly. **It is a implementation of a user space vhost
interface.**

The implementation is:

- -mem-path option to allocate guest RAM as memory that can be shared with
  another process

- User a Unix domain socket to communicate between QEMU and the user space vhost

- The user space application will receive file descriptors for the pre-allocated
  shared guest RAM. It will directly access the related vrings in the memory
  space of guest.

The vhost client is in QEMU and the backend is *Snabbswitch*.

The usage in QEMU is like following:

	$ qemu -m 1024 -mem-path /hugetlbfs,prealloc=on,share=on \
	-netdev type=vhost-user,id=net0,file=/path/to/socket \
	-device virtio-net-pci,netdev=net0

---

An article at Virtual Open Systems: [Vhost-User Feature for QEMU](http://www.virtualopensystems.com/en/solutions/guides/snabbswitch-qemu/)  
Another article compare vhost with vhost-user: <http://www.51gocloud.com/?p=402>
