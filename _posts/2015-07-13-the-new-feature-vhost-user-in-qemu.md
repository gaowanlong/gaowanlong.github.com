---
layout: post
title: "The new feature vhost-user in QEMU"
description: "Vhost-user applied to snabbswitch ethernet switch"
category: Virtualization
tags: [kvm, qemu, virtio]
---

#### virtio-net
The QEMU/KVM guest can access external network via virtio-net. QEMU emulated a
PCI device via virtio_pci, servers as the transport mechanism that implements
the Virtio ring. Virtio drivers lies on top of it to set up virtqueues, that
will be 'kicked' whenever buffers with new data are placed in them.  Virtio-net
is a network implementation on virtio. Guest running virtio-net will share a
number of virtqueues with QEMU process.  So, QEMU should process the network
traffic before it can be processed further by the network stack of host.

#### vhost-net#
Then the vhost can **accelerate** the above process by **directly pass guest
network traffic to TUN device directly from the kernel side**. In this model,
QEMU will pass direct control of a virtqueue to a kernel driver.

#### vhost-user#
While vhost-user want to event skip the kernel part and process the network
traffic in userspace directly. **It is a implementation of a user space vhost
interface.**

*The implementation is*:

- -mem-path option to allocate guest RAM as memory that can be shared with
  another process

- User a Unix domain socket to communicate between QEMU and the user space vhost

- The user space application will receive file descriptors for the pre-allocated
  shared guest RAM. It will directly access the related vrings in the memory
  space of guest.

The vhost client is in QEMU and the backend is *Snabbswitch*.

Example usage:

```shell
qemu -m 512 \
     -object memory-file,id=mem,size=512M,mem-path=/hugetlbfs,share=on \
     -numa node,memdev=mem \
     -chardev socket,id=chr0,path=/path/to/socket \
     -netdev type=vhost-user,id=net0,chardev=chr0 \
     -device virtio-net-pci,netdev=net0
```

#### VhostUser App (apps.vhost.vhost_user)#
The SnabbSwitch architecture can be described to **Snabb Switch Core** with
**custom Apps and Libraries**. The *Core* is the basic Snabb Switch stack and provides
a runtime environment(engine). While the *Apps* are *Lua script* used to drive
the core stack. The job of the core engine is:

- Pump traffic through the app network
- Keep the app network running(eg. restart failed apps)
- Report on the network status

Through above description, we want to say that VhostUser is one of
the Apps in SnabbSwitch. VhostUser app supports the virtio vring date structure
for packet I/O in shared memory(DMA) and the Linux vhost API for creating vrings
attached to tuntap devices.

#### What is TUN/TAP device#
TUN/TAP provides packet reception and transmission for user space programs. It can
be seen as a simple Point-to-Point or Ethernet device, which, instead of receiving
packets from physical media, receives them from user space program and instead of
sending packets via physical media writes them to the user space program.

*Open /dev/net/tun and issue a ioctl() to use the driver*. The ioctl() option will
determine the network device type and name, tunXX or tapXX will appear.

> tunXX <===(read/write)===> IP packets  
> tapXX <===(read/write)===> ethernet frames

---

The vhost-user support patch series: <http://lists.gnu.org/archive/html/qemu-devel/2014-05/msg05443.html>  
An article at Virtual Open Systems: [Vhost-User Feature for QEMU](http://www.virtualopensystems.com/en/solutions/guides/snabbswitch-qemu/)  
Another article compare vhost with vhost-user: <http://www.51gocloud.com/?p=402>  
Universal TUN/TAP driver: <https://www.kernel.org/doc/Documentation/networking/tuntap.txt>
