---
layout: post
title: "virtio 9p note"
description: "virtio 9p filesystem notes"
category: virtualization
tags: [9p, virtio, kvm]
---
{% include JB/setup %}

KVM introduces a new and more optimized tool called VirtFS (sometimes referred
to as a file system pass-through). VirtFS uses a paravirtual file system driver,
which avoids converting the guest application file system operations into block
device operations, and then again into host file system operations. VirtFS uses
Plan-9 network protocol for communication between the guest and the host.

You can typically use VirtFS to:

* access a shared folder from several guests, or to provide guest-to-guest
  file system access.

* replace the virtual disk as the root file system to which the guest's ramdisk
  connects to during the guest boot process

* provide storage services to different customers from a single host file
  system in a cloud environment

In QEMU, the implementation of VirtFS is facilitated by defining two types of
devices:

* virtio-9p-pci device which transports protocol messages and data between the
  host and the guest.

* fsdev device which defines the export file system properties, such as file
  system type and security model.

Exporting Host's Filesystem with VirtFS

	qemu-kvm [...] -fsdev local,id=exp1,path=/tmp/,security_model=mapped
	-device virtio-9p-pci,fsdev=exp1,mount_tag=v_tmp

In above:

* id=exp1: Identification of the file system to be exported.

* path=/tmp/: Filesystem path on the host to be exported.

* security_model=mapped: Security model to be used—mapped keeps the guest file
  system modes and permissions isolated from the host, while none invokes a
  pass-through security model in which permission changes on the guest's files
  are reflected on the host as well.

* fsdev=exp1: The exported file system ID defined before with -fsdev id= .

* mount_tag=v_tmp: Mount tag used later on the guest to mount the exported
  file system.

Such an exported file system can be mounted on the guest like this

	mount -t 9p -o trans=virtio v_tmp /mnt

where v_tmp is the mount tag defined earlier with -device mount_tag= and /mnt
is the mount point where you want to mount the exported file system.

---

###Can 9p used as root file system?

For example, we can add 9p modules to the host initramfs and boot up a guest
use host kernel and host initramfs in which 9p module is added:

	printf '%s\n' 9p 9pnet 9pnet_virtio | sudo tee -a /etc/initramfs-tools/modules
	sudo update-initramfs -u

	qemu -kernel "/boot/vmlinuz-$(uname -r)" \
	  -initrd "/boot/initrd.img-$(uname -r)" \
	  -fsdev local,id=r,path=/,security_model=none \
	  -device virtio-9p-pci,fsdev=r,mount_tag=r \
	  -nographic \
	  -append 'root=r ro rootfstype=9p rootflags=trans=virtio console=ttyS0 init=/bin/sh'

Additionally use "security_model=mapped" to be able to fully access the underlying
filesystem since it stores owership and other privileged file information in extended
attributes of the file. This also allows to mount the fs read-write instead of read-only.

This answer refer to: <http://unix.stackexchange.com/a/94253>

---

The above mentioned security model is explained below:

####Security model: mapped

VirtFS server(QEMU) intercepts and maps all the file object create requests.
Files on the fileserver will be created with QEMU's user credentials and the
client-user's credentials are stored in extended attributes.
During getattr() server extracts the client-user's credentials from extended
attributes and sends to the client.

Given that only the user space extended attributes are available to regular
files, special files are created as regular files on the fileserver and the
appropriate mode bits are stored in xattrs and will be extracted during
getattr.

If the extended attributes are missing, server sends back the filesystem
stat() unaltered. This provision will make the files created on the
fileserver usable to client.

Points to be considered

* Filesystem will be VirtFS'ized. Meaning, other filesystems may not
  understand the credentials of the files created under this model.

* Regular utilities like 'df' may not report required results in this model.
  Need for special reporting utilities which can understand this security model.


####Security model : passthrough

In this security model, VirtFS server passes down all requests to the
underlying filesystem. File system objects on the fileserver will be created
with client-user's credentials. This is done by setting setuid()/setgid()
during creation or ch* after file creation. At the end of create protocol
request, files on the fileserver will be owned by client-user's uid/gid.

Points to be considered

  * Fileserver should always run as 'root'.
  * Root squashing may be needed. Will be for future work.
  * Potential for user credential clash between guest's user space IDs and
    host's user space IDs.

It also adds security model attribute to -fsdev device and to -virtfs shortcut.

Usage examples:

	-fsdev local,id=jvrao,path=/tmp/,security_model=mapped
	-virtfs local,path=/tmp/,security_model=passthrough,mnt_tag=v_tmp.

---
9p doc in kernel: <https://www.kernel.org/doc/Documentation/filesystems/9p.txt>

9p RFC is maintained on github: <https://github.com/ericvh/9p-rfc>

Qemu docs for setup VirtFS: <http://wiki.qemu.org/Documentation/9psetup>

9p patch mail in qemu: <https://lists.gnu.org/archive/html/qemu-devel/2010-05/msg02673.html>
