---
layout: post
title: "KVM irqfd and ioeventfd"
description: ""
category: kvm
tags: [ioeventfd, irqfd, kvm]
---
{% include JB/setup %}

In previous article [vhost architecture](http://blog.allenx.org/linux/2013/09/09/vhost-architecture/)
we mentioned that vhost and the guest signal each other by irqfd and ioeventfd mechanism.

So let us see how irqfd and ioeventfd mechanism can take this role. We can find
the patches in linus tree which implement them:

KVM irqfd support patch: <http://git.kernel.org/linus/721eecbf4fe995ca94a9edec0c9843b1cc0eaaf3>  
KVM ioeventfd support patch: <http://git.kernel.org/linus/d34e6b175e61821026893ec5298cc8e7558df43a>

---

####irqfd#

irqfd is a mechanism to inject a specific interrupt to a guest using a decoupled
eventfd mechanism: Any legal signal on the irqfd (using eventfd semantics from
either userspace or kernel) will translate into an injected interrupt in the guest
at the next interrupt window.

One line description is:

> irqfd: Allows an fd to be used to inject an interrupt to the guest

Go into the patch, we can see details:

Hook the irq inject wakeup function to a wait queue, and the wait queue will
be added by the eventfd polling callback.
