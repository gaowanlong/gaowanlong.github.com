---
layout: post
title: "KVM irqfd and ioeventfd"
description: ""
category: virtualization
tags: [kvm]
---

In previous article [vhost architecture](http://blog.allenx.org/2013/09/09/vhost-architecture/)
we mentioned that vhost and the guest signal each other by irqfd and ioeventfd mechanism.

So let us see how irqfd and ioeventfd mechanism can take this role. We can find
the patches in linus tree which implement them:

KVM irqfd support patch: <http://git.kernel.org/linus/721eecbf4fe995ca94a9edec0c9843b1cc0eaaf3>  
KVM ioeventfd support patch: <http://git.kernel.org/linus/d34e6b175e61821026893ec5298cc8e7558df43a>

---

#### irqfd#

irqfd is a mechanism to inject a specific interrupt to a guest using a decoupled
eventfd mechanism: Any legal signal on the irqfd (using eventfd semantics from
either userspace or kernel) will translate into an injected interrupt in the guest
at the next interrupt window.

One line description is:

> irqfd: Allows an fd to be used to inject an interrupt to the guest

Go into the patch, we can see details:

Hook the irq inject wakeup function to a wait queue, and the wait queue will
be added by the eventfd polling callback.

#### ioeventfd#

While ioeventfd is a mechanism to register PIO/MMIO regions to trigger an eventfd
signal when written to by a guest. The purpose of this mechanism is to make
guest notify host in a lightweight way. This is lightweight because it will not
cause a VMX/SVM exit back to userspace, serviced by qemu then returning control
back to the vcpu.  Why we need this mechanism because this kind of *heavy-weight*
IO sync mechanism is not necessary for the triggers, these triggers only want
to transmit a notify asynchronously and return as quickly as possible. It is
expansive for them to use the normal IO.

Look into the implementation, it accepts the eventfd and io address from args,
then register a kvm_io_device with them. And the write operation of the registered
kvm_io_device is sending an eventfd signal. The signal function is eventfd_siganl().

So, this mechanism is:

> ioeventfd: Allow an fd to be used to receive a signal from the guest

#### conclusion#

A very simple conclusion of these two mechanism can be the following picture:

	+-----------------------------------------+
	|                                  Host   |
	|   +--------------------------+          |
	|   |                QEMU      |          |
	|   |                          |          |
	|   |      +---------------+   |          |
	|   |      |      Guest    |   |          |
	|   |      |               |   |          |
	|   |      |   +-------- ioeventfd------> |
	|   |      |               |   |          |
	|   |      |               |   |          |
	|   |      |               |   |          |
	|   |      |   <-----------irqfd--------+ |
	|   |      |               |   |          |
	|   |      +---------------+   |          |
	|   |                          |          |
	|   |                          |          |
	|   +--------------------------+          |
	|                                         |
	+-----------------------------------------+

After knowing what irqfd and ioeventfd are and how they are implemented, the next
section may be how to use them, for example in vhost? ;)
