---
layout: post
title: "On the way of testing and improving the performance of virtio-scsi"
description: ""
category: Linux
tags: [virtio]
---
{% include JB/setup %}

### My QEMU command line when testing virtio-scsi ##
#### Get the qemu command line from libvirt XML ##
Modify the libvirt in order to print the command line when starting a VM

	diff --git a/src/util/command.c b/src/util/command.c
	index ebdd636..9f242a4 100644
	--- a/src/util/command.c
	+++ b/src/util/command.c
	@@ -2197,7 +2197,7 @@ virCommandRunAsync(virCommandPtr cmd, pid_t *pid)
	     }
	 
	     str = virCommandToString(cmd);
	-    VIR_DEBUG("About to run %s", str ? str : cmd->args[0]);
	+    VIR_WARN("About to run %s", str ? str : cmd->args[0]);
	     VIR_FREE(str);
	 
	     ret = virExecWithHook((const char *const *)cmd->args,

#### Run libvirtd and start the GUEST by virsh. #
We can get the QEMU command line from the message printed by libvirtd

	# libvirtd
	# virsh start f17
#### Another more simpler method no need to modify libvirt code ##

	# service libvirtd start
	# virsh start f17
	# ps aux | grep qemu

### My QEMU command line ##
With 4 targets, 2 virtio-blk disks, 4 virtio-scsi targets, 1 lun each target.
While "-monitor stdio" add the qemu monitor controller to stdio.

	/work/git/qemu/x86_64-softmmu/qemu-system-x86_64 -name f17 -M pc-0.15 -enable-kvm -m 3096 \
	-smp 4,sockets=4,cores=1,threads=1 \
	-uuid c31a9f3e-4161-c53a-339c-5dc36d0497cb -no-user-config -nodefaults \
	-chardev socket,id=charmonitor,path=/var/lib/libvirt/qemu/f17.monitor,server,nowait \
	-mon chardev=charmonitor,id=monitor,mode=control \
	-rtc base=utc -no-shutdown \
	-device piix3-usb-uhci,id=usb,bus=pci.0,addr=0x1.0x2 \
	-device virtio-scsi-pci,id=scsi0,bus=pci.0,addr=0xb,num_queues=4,hotplug=on \
	-device virtio-serial-pci,id=virtio-serial0,bus=pci.0,addr=0x5 \
	-drive file=/vm/f17.img,if=none,id=drive-virtio-disk0,format=qcow2 \
	-device virtio-blk-pci,scsi=off,bus=pci.0,addr=0x6,drive=drive-virtio-disk0,id=virtio-disk0,bootindex=1 \
	-drive file=/vm2/f17-kernel.img,if=none,id=drive-virtio-disk1,format=qcow2 \
	-device virtio-blk-pci,scsi=off,bus=pci.0,addr=0x8,drive=drive-virtio-disk1,id=virtio-disk1 \
	-drive file=/vm/virtio-scsi/scsi3.img,if=none,id=drive-scsi0-0-2-0,format=raw \
	-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=2,lun=0,drive=drive-scsi0-0-2-0,id=scsi0-0-2-0,removable=on \
	-drive file=/vm/virtio-scsi/scsi4.img,if=none,id=drive-scsi0-0-3-0,format=raw \
	-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=3,lun=0,drive=drive-scsi0-0-3-0,id=scsi0-0-3-0 \
	-drive file=/vm/virtio-scsi/scsi1.img,if=none,id=drive-scsi0-0-0-0,format=raw \
	-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=0,lun=0,drive=drive-scsi0-0-0-0,id=scsi0-0-0-0 \
	-drive file=/vm/virtio-scsi/scsi2.img,if=none,id=drive-scsi0-0-1-0,format=raw \
	-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=1,lun=0,drive=drive-scsi0-0-1-0,id=scsi0-0-1-0 \
	-chardev pty,id=charserial0 -device isa-serial,chardev=charserial0,id=serial0 \
	-chardev file,id=charserial1,path=/vm/f17.log \
	-device isa-serial,chardev=charserial1,id=serial1 \
	-device usb-tablet,id=input0 -vga std \
	-device virtio-balloon-pci,id=balloon0,bus=pci.0,addr=0x7 \
	-monitor stdio

The XML format of 4 targets, 1 lun with each target
	    <disk type='file' device='disk'>
	      <driver name='qemu' type='raw'/>
	      <source file='/vm/virtio-scsi/scsi3.img'/>
	      <target dev='sda' bus='scsi'/>
	      <alias name='scsi0-0-2-0'/>
	      <address type='drive' controller='0' bus='0' target='2' unit='0'/>
	    </disk>
	    <disk type='file' device='disk'>
	      <driver name='qemu' type='raw'/>
	      <source file='/vm/virtio-scsi/scsi4.img'/>
	      <target dev='sda' bus='scsi'/>
	      <alias name='scsi0-0-3-0'/>
	      <address type='drive' controller='0' bus='0' target='3' unit='0'/>
	    </disk>
	    <disk type='file' device='disk'>
	      <driver name='qemu' type='raw'/>
	      <source file='/vm/virtio-scsi/scsi1.img'/>
	      <target dev='sdb' bus='scsi'/>
	      <alias name='scsi0-0-0-0'/>
	      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
	    </disk>
	    <disk type='file' device='disk'>
	      <driver name='qemu' type='raw'/>
	      <source file='/vm/virtio-scsi/scsi2.img'/>
	      <target dev='sdb' bus='scsi'/>
	      <alias name='scsi0-0-1-0'/>
	      <address type='drive' controller='0' bus='0' target='1' unit='0'/>
	    </disk>
	

The above mentioned scsiX.img are all tmpfs backed images

	# cat /vm/scsi.sh 
	#!/bin/bash
	mount -t tmpfs scsi -o size=3G /vm/virtio-scsi
	dd if=/dev/zero of=/vm/virtio-scsi/scsi1.img bs=1M count=700
	dd if=/dev/zero of=/vm/virtio-scsi/scsi2.img bs=1M count=700
	dd if=/dev/zero of=/vm/virtio-scsi/scsi3.img bs=1M count=700
	dd if=/dev/zero of=/vm/virtio-scsi/scsi4.img bs=1M count=700
