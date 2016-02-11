---
layout: post
title: "QEMU KVM VCPU internal"
description: ""
category: Virtualization
tags: [kvm, qemu]
---

VCPU is neither a OS thread nor a process. To understand how VCPU works,
first we should figure out how guest OS is running on Intel VT-x architecture.

Intel VT-x proposed a new mode methodology with two modes: VMX root mode and
VMX non-root mode, for running host VMM and guest respectively. Intel VT-x
also contains a new structure: VMCS, which saves all information both host
and guest need. VMCS is one per guest.

KVM is a hardware-assisted hypervisor and leverages Intel VT-x. The host Linux
KVM is running in VMX root mode. When KVM decides to switch CPU mode to run a
guest, KVM dumps all current contexts to VMCS and executes a "VMLAUNCH"
instruction. "VMLAUNCH" will transfer CPU from VMX root mode to VMX non-root
mode, and load guest context from VMCS, then start or continue to execute
guest code.

In summary, the guest code is running directly on CPU in VMX non-root mode.
no software emulation layer for VCPU is needed. That's why KVM has better
performance, and there is no specific thread for guest.

/dev/kvm is created by kvm.ko, which is only a KVM interface for QEMU. Your
strace output showed how QEMU was interacting with KVM and controlling the
underlying guests. You can never find a fork or clone system call in KVM.

For more KVM detail especially VCPU, you can read KVM code in
arch/x86/kvm/vmx.c for more VCPU implementation detail based on Intel VT-x.


I found this short good answer from stackoverflow.com:
<http://stackoverflow.com/a/18595619/4557496>

---

### KVM Execution Model#

```
+----------------+   +-----------------+   +-----------------+
|    Userspace   |   |      Kernel     |   |     Guest       |
|        +---------KVMRUN------+       |   |                 |
|   +----------+ |   |         |       |   |                 |
| +-> ioctl()  | |   |    +----v-----+ |   |                 |
| | |          | |   |    |switch to +-----VMENTER----+      |
| | +----------+ |   | +-->guest mode| |   |  +-------v----+ |
| |              |   | |  +----------+ |   |  |Native guest| |
| |              |   | |               |   |  |execution   | |
| |              |   | |               |   |  |            | |
| |              |   | |               |   |  +-------+----+ |
| |  +---------+ |   | |  +----------+ |   |          |      |
| |  |Userspace| |   | |  | Kernel   | |   |          |      |
| +--+exit     | |   | +--+ exit     | |   |VMEXIT    |      |
|    |handler  | |   |    | handler  <----------------+      |
|    +---^-----+ |   |    +----------+ |   |                 |
|        |---------------------|       |   |                 |
+----------------+   +-----------------+   +-----------------+
```
