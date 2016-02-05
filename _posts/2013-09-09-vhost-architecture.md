---
layout: post
title: "vhost architecture"
description: ""
category: virtualization
tags: [vhost, qemu, kvm]
---


###Vhost overview

The vhost drivers in Linux provide in-kernel virtio device emulation.
Normally the QEMU userspace process emulates I/O accesses from the guest.
Vhost puts virtio emulation code into the kernel, taking QEMU userspace out
of the picture. This allows device emulation code to directly call into kernel
subsystems instead of performing system calls from userspace.

The vhost-net driver emulates the virtio-net network card in the host kernel.
Vhost-net is the oldest vhost device and the only one which is available in
mainline Linux. Experimental vhost-blk and vhost-scsi devices have also been developed.

In Linux 3.0 the vhost code lives in drivers/vhost/. Common code that is used by all
devices is in drivers/vhost/vhost.c. This includes the virtio vring access functions
which all virtio devices need in order to communicate with the guest. The vhost-net
code lives in drivers/vhost/net.c.

###The vhost driver model

The vhost-net driver creates a /dev/vhost-net character device on the host.
This character device serves as the interface for configuring the vhost-net instance.

When QEMU is launched with -netdev tap,vhost=on it opens /dev/vhost-net and initializes
the vhost-net instance with several ioctl(2) calls. These are necessary to associate the
QEMU process with the vhost-net instance, prepare for virtio feature negotiation, and pass
the guest physical memory mapping to the vhost-net driver.

During initialization the vhost driver creates a kernel thread called vhost-$pid,
where $pid is the QEMU process pid. This thread is called the "vhost worker thread".
The job of the worker thread is to **handle I/O events and perform the device emulation.**

>vhost初始化时创建vhost-$pid内核线程来处理I/O事件和模拟设备。

###In-kernel virtio emulation

Vhost does not emulate a complete virtio PCI adapter. Instead it restricts itself to
virtqueue operations only. QEMU is still used to perform virtio feature negotiation
and live migration, for example. This means a vhost driver is not a self-contained virtio
device implementation, it depends on userspace to handle the control plane while the data
plane is done in-kernel.

> Vhost 实际上并不是完整的virtio PCI适配器，它仍要依赖qemu来模拟virtio设备，只是把
> 数据处理的部分放到kernel里面来做。

The vhost worker thread waits for virtqueue kicks and then handles buffers that have been
placed on the virtqueue. In vhost-net this means taking packets from the tx virtqueue and
transmitting them over the tap file descriptor.

File descriptor polling is also done by the vhost worker thread. In vhost-net the worker
thread wakes up when packets come in over the tap file descriptor and it places them into
the rx virtqueue so the guest can receive them.

###Vhost as a userspace interface

One surprising aspect of the vhost architecture is that it is not tied to KVM in any way.
Vhost is a userspace interface and has no dependency on the KVM kernel module. This means
other userspace code, like libpcap, could in theory use vhost devices if they find them
convenient high-performance I/O interfaces.

When a guest kicks the host because it has placed buffers onto a virtqueue, there needs to
be a way to signal the vhost worker thread that there is work to do. Since vhost does not
depend on the KVM kernel module they cannot communicate directly. Instead vhost instances
are set up with an eventfd file descriptor which the vhost worker thread watches for activity.
The KVM kernel module has a feature known as ioeventfd for taking an eventfd and hooking it up
to a particular guest I/O exit. QEMU userspace registers an ioeventfd for the
VIRTIO_PCI_QUEUE_NOTIFY hardware register access which kicks the virtqueue. This is how the
vhost worker thread gets notified by the KVM kernel module when the guest kicks the virtqueue.

> vhost和KVM模块是相互独立的，vhost会创建eventfd并且watch它的状态。同时QEMU将ioeventfd注册成
> guest的queue notify硬件寄存器。因此当guest kick virtqueue的时候，vhost内核线程就会收到信号。

On the return trip from the vhost worker thread to interrupting the guest a similar approach
is used. Vhost takes a "call" file descriptor which it will write to in order to kick the guest.
The KVM kernel module has a feature called irqfd which allows an eventfd to trigger guest interrupts.
QEMU userspace registers an irqfd for the virtio PCI device interrupt and hands it to the vhost
instance. This is how the vhost worker thread can interrupt the guest.

In the end the vhost instance only knows about the guest memory mapping, a kick eventfd,
and a call eventfd.

> 因为vhost共享得到了需要传输的vring队列的memory mapping, 所以省去了队列从guest到Host userspace
> 再到Host Kernel的多次跨态拷贝，所以加快了速度。

> 基本思想是将vring的数据处理推迟到Host Kernel中进行，使得处理前的vring保持可共享状态.

###Where to find out more
Here are the main points to begin exploring the code:

    drivers/vhost/vhost.c - common vhost driver code
    drivers/vhost/net.c - vhost-net driver
    virt/kvm/eventfd.c - ioeventfd and irqfd

The QEMU userspace code shows how to initialize the vhost instance:

    hw/vhost.c - common vhost initialization code
    hw/vhost_net.c - vhost-net initialization


This nice article is copied from Stefan's Blog:
<http://blog.vmsplice.net/2011/09/qemu-internals-vhost-architecture.html>

---

####virtio-net and vhost-net architecture#


Vhost-net improvement is:

- Less context switching
- Low latency
- MSI
- One less copy

The following two pictures describe the normal virtio-net architecture and the
in kernel vhost-net architecture, we can get a clear sense of them from these two
pictures.

![virtio-net](http://7xky0k.com1.z0.glb.clouddn.com/virtio-net.jpg)
![vhost-net](http://7xky0k.com1.z0.glb.clouddn.com/vhost-net.jpg)


---
