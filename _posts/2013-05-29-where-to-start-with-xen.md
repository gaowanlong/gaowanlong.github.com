---
layout: post
title: "Where to start with Xen?"
description: ""
category: virtualization
tags: [xen]
---

While this is a newbie question about Xen.
I just found a very good answer for this question on Stack Overflow,
the original link is here [Where to start with Xen](http://stackoverflow.com/questions/11575299/where-to-start-with-xen).

The following is the answer:

	Since you mention looking at the code, I assume you want to understand the technical details of Xen and not just merely how to start a VM.

	As with all problems, start with something simple and then work your way up. Some pointers:

    Be sure to have the prerequisite experience under your belt. In particular, strong C and Linux affinity, but also x86 paging and virtualized memory workings.

    Make sure you have a sound grasp of the general Xen architecture. For instance, paravirtualized versus hardware-supported virtualization, the special role of the management domain (Dom0) compared to unprivileged domains (DomU), etc.

    Investigate the the Xen components running in Dom0:

        The Xen control library (libxc) which implements much of the logic relating to hypercalls and adds sugar around these (look in tools/libxc).

        The swiss army knife for administrating Xen, namely the Xen light library (libxl). This library replaces the deprecated xm tool with the xl tool and takes care of all your maintenance tasks such as starting/stopping a VM, listing all running VMs, etc. For all these operations, it works in tandem with the aforementioned libxc. (Libxl lives in tools/libxl.)

        The Xenstore is a tree-like data structure from which all running domains can retrieve and store data. This is necessary since all I/O goes through Dom0 (not the hypervisor!), and domains need to communicate with Dom0 how they are going to pass I/O along. (Look in tools/xenstore.) You can inspect the Xenstore with a tool such as xenstore-ls.

        the blkback/netback kernel drivers which pass the data over shared channels to the VMs. (You will find these drivers in a recent Linux kernel (e.g. >= v3.0) that has so-called PVOPS support).

        Take a look at the console daemon (tools/console). Note that sometimes the Qemu console is actually used. Qemu also comes in the pictures as a default backend for if you choose a file-backed virtual storage for a VM.

    Experiment with the 'Xen-way' of inter-VM communication: Grant tables, event channels and the Xenstore. With these fundamentals you can create your own shared channel between VMs. You can do this, for example, with writing a kernel module that you use in two domains to let them talk to each other.

    I can also give some pointers in the source that you can check out:

        xen/xen/include/public/xen.h will give you a list of all the hypercalls with comments what they do.

        xen/xen/include/xen/mm.h gives you an introduction to the different memory terminology used by Xen (i.e., real versus virtualized addresses and page numbers). If you don't grasp these differences, then reading the hypervisor code will surely be frustrating.

        xen/xen/include/asm-x86/config.h gives an overview of the memory layout of Xen.

        xen/tools/libxc/xenctrl.h exports a large list of interesting domain control operations, which gives an abstract view of task division between Dom0 and the hypervisor.

	Last but not least, the book 'The Definitive Guide to the Xen Hypervisor' by David Chisnall comes highly recommended. It covers all these topics and more in a thorough, technical fashion with plenty of code examples.

	The Xen wiki and developer mailing lists are also a great resource for understanding Xen.

	If you have a more specific question, then I can give you a more specific answer.

