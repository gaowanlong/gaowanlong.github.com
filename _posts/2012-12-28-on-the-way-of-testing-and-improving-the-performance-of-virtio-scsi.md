---
layout: post
title: "On the way of testing and improving the performance of virtio-scsi"
description: ""
category: Virtualization
tags: [virtio, kvm]
---

### My QEMU command line when testing virtio-scsi

#### Get the qemu command line from libvirt XML

Modify the libvirt in order to print the command line when starting a VM

```diff
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
```

> It also possible to get the QEMU command line from ps command when running the
> guest using libvirt. -2015-06-29

```shell
ps aux | grep qemu
```


#### Compile libvirt and QEMU
I always install the upstream libvirt to my system

```diff
$ git diff
diff --git a/.gitmodules b/.gitmodules
index 7acb1ea..e67ffdb 100644
--- a/.gitmodules
+++ b/.gitmodules
@@ -1,3 +1,3 @@
 [submodule "gnulib"]
	path = .gnulib
-       url = git://git.sv.gnu.org/gnulib.git
+       url = git://10.167.225.115/git/gnulib
$ ./autogen.sh --prefix=/usr --libdir=/usr/lib64 && make && sudo make install
```

But not install QEMU, just use the compiled binary to start QEMU

```shell
$ ./configure --target-list=x86_64-softmmu --enable-kvm
# /work/git/qemu/x86_64-softmmu/qemu-system-x86_64 ... ...
```


#### Run libvirtd and start the GUEST by virsh. #
We can get the QEMU command line from the message printed by libvirtd

```shell
# libvirtd
# virsh start f17
```
#### Another more simpler method no need to modify libvirt code ##

```shell
# service libvirtd start
# virsh start f17
# ps aux | grep qemu
```

### My QEMU command line ##
With 4 targets, 2 virtio-blk disks, 4 virtio-scsi targets, 1 lun each target.
While "-monitor stdio" add the qemu monitor controller to stdio.

```shell
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
```

The XML format of 4 targets, 1 lun with each target

```xml
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
```
	

The above mentioned scsiX.img are all tmpfs backed images

```shell
# cat /vm/scsi.sh 
#!/bin/bash
mount -t tmpfs scsi -o size=3G /vm/virtio-scsi
dd if=/dev/zero of=/vm/virtio-scsi/scsi1.img bs=1M count=700
dd if=/dev/zero of=/vm/virtio-scsi/scsi2.img bs=1M count=700
dd if=/dev/zero of=/vm/virtio-scsi/scsi3.img bs=1M count=700
dd if=/dev/zero of=/vm/virtio-scsi/scsi4.img bs=1M count=700
```

### Hot-plug and Hot-unplug a virtio-scsi device ##

```shell
qemu> drive_add 0:11 file=/vm/virtio-scsi/scsi4.img,if=none,id=hotadd-scsi1,format=raw
qemu> device_add scsi-hd,bus=scsi0.0,scsi-id=4,lun=0,drive=hotadd-scsi1,id=hotadd-scsi1
qemu> device_del hotadd-scsi1
```

### Virtio-scsi performance testing

#### Use the upstream fio

```shell
git clone http://git.kernel.org/pub/scm/linux/kernel/git/axboe/fio.git
```

#### fio configuration file ##

```conf
# cat virtio-scsi-4.fio 
[global]
bsrange=4k-64k
ioengine=libaio
direct=1
iodepth=4
loops=100
size=700M
write_bw_log=virtio-scsi_1.log

[randrw]
rw=randrw
filename=/dev/sda:/dev/sdb:/dev/sdc:/dev/sdd
```

#### We always use irqbalance to improve the performance of virtio-scsi ##

```shell
# git clone http://code.google.com/p/irqbalance
```

#### We can also test the performance using idle=poll on host to avoid power management effect. ##

The method is adding idle=poll parameter to host kernel.
Quoted from M.S.T:

>"Another thing to note is that ATM you might need to
>test with idle=poll on host otherwise we have strange interaction
>with power management where reducing the overhead
>switches to lower power so gives you a worse IOPS."

#### run fio with the fio configuration file ##

```shell
# fio virtio-scsi-4.fio --output=scsi-4.log
```

### Use virtio-net in QEMU command line ##
If we want to start QEMU by hand, we should set up the tap device by ourselves.
The following simple program just set up the tap device and open the vhost-net
device and start the QEMU. It's useful when debugging virtio devices in QEMU.

#### This is the 4 tagets, 1 lun each target command line. ##

```c
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <net/if.h>
#include <linux/if_tun.h>

int main(int argc, char **argv)
{
	pid_t pid;
	int status;
	int tap_fd = open("/dev/net/tun", O_RDWR);
	int vhost_fd = open("/dev/vhost-net", O_RDWR);
	char *tap_name = "tap";
	char cmd[2048];
	char brctl[256];
	char netup[256];
	struct ifreq ifr;
	if (tap_fd < 0) {
		printf("open tun device failed\n");
		return -1;
	}
	if (vhost_fd < 0) {
		printf("open vhost-net device failed\n");
		return -1;
	}
	memset(&ifr, 0, sizeof(ifr));
	memcpy(ifr.ifr_name, tap_name, sizeof(tap_name));
	ifr.ifr_flags = IFF_TAP | IFF_NO_PI;

	/*
	 * setup tap net device
	 */
	if (ioctl(tap_fd, TUNSETIFF, &ifr) < 0) {
		printf("setup tap net device failed\n");
		return -1;
	}

	sprintf(brctl, "brctl addif virbr0 %s", tap_name);
	sprintf(netup, "ifconfig %s up", tap_name);
	sprintf(cmd, "/work/git/qemu/x86_64-softmmu/qemu-system-x86_64 -name f17 -M pc-0.15 -enable-kvm -m 3096 \
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
-netdev tap,fd=%d,id=hostnet0,vhost=on,vhostfd=%d \
-device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:ce:7b:29,bus=pci.0,addr=0x3 \
-monitor stdio", tap_fd, vhost_fd);

	pid = fork();
	if (pid < 0) {
		return -1;
	} else if (pid == 0) {
		system(brctl);
		system(netup);
		system(cmd);
		return 0;
	}

	sleep(1);
	wait(&status);
	close(tap_fd);
	close(vhost_fd);
	return 0;
}
```

#### Then this is the 1 target, 4 luns each target command line. ##

```c
	sprintf(cmd, "/work/git/qemu/x86_64-softmmu/qemu-system-x86_64 -name f17 -M pc-0.15 -enable-kvm -m 3096 \
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
-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=0,lun=2,drive=drive-scsi0-0-2-0,id=scsi0-0-2-0,removable=on \
-drive file=/vm/virtio-scsi/scsi4.img,if=none,id=drive-scsi0-0-3-0,format=raw \
-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=0,lun=3,drive=drive-scsi0-0-3-0,id=scsi0-0-3-0 \
-drive file=/vm/virtio-scsi/scsi1.img,if=none,id=drive-scsi0-0-0-0,format=raw \
-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=0,lun=0,drive=drive-scsi0-0-0-0,id=scsi0-0-0-0 \
-drive file=/vm/virtio-scsi/scsi2.img,if=none,id=drive-scsi0-0-1-0,format=raw \
-device scsi-hd,bus=scsi0.0,channel=0,scsi-id=0,lun=1,drive=drive-scsi0-0-1-0,id=scsi0-0-1-0 \
-chardev pty,id=charserial0 -device isa-serial,chardev=charserial0,id=serial0 \
-chardev file,id=charserial1,path=/vm/f17.log \
-device isa-serial,chardev=charserial1,id=serial1 \
-device usb-tablet,id=input0 -vga std \
-device virtio-balloon-pci,id=balloon0,bus=pci.0,addr=0x7 \
-netdev tap,fd=%d,id=hostnet0,vhost=on,vhostfd=%d \
-device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:ce:7b:29,bus=pci.0,addr=0x3 \
-monitor stdio", tap_fd, vhost_fd);
```

#### While this is the virtio-blk command line, with 4 test virtio-blk, /dev/vd\[c-f\]. ##

```c
	sprintf(cmd, "/work/git/qemu/x86_64-softmmu/qemu-system-x86_64 -name f17 -M pc-0.15 -enable-kvm -m 3096 \
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
-drive file=/vm/virtio-scsi/scsi3.img,if=none,id=drive-virtio-disk2,format=raw \
-device virtio-blk-pci,scsi=off,bus=pci.0,addr=0x9,drive=drive-virtio-disk2,id=virtio-disk2 \
-drive file=/vm/virtio-scsi/scsi4.img,if=none,id=drive-virtio-disk3,format=raw \
-device virtio-blk-pci,scsi=off,bus=pci.0,addr=0xa,drive=drive-virtio-disk3,id=virtio-disk3 \
-drive file=/vm/virtio-scsi/scsi1.img,if=none,id=drive-virtio-disk4,format=raw \
-device virtio-blk-pci,scsi=off,bus=pci.0,addr=0xc,drive=drive-virtio-disk4,id=virtio-disk4 \
-drive file=/vm/virtio-scsi/scsi2.img,if=none,id=drive-virtio-disk5,format=raw \
-device virtio-blk-pci,scsi=off,bus=pci.0,addr=0xd,drive=drive-virtio-disk5,id=virtio-disk5 \
-chardev pty,id=charserial0 -device isa-serial,chardev=charserial0,id=serial0 \
-chardev file,id=charserial1,path=/vm/f17.log \
-device isa-serial,chardev=charserial1,id=serial1 \
-device usb-tablet,id=input0 -vga std \
-device virtio-balloon-pci,id=balloon0,bus=pci.0,addr=0x7 \
-netdev tap,fd=%d,id=hostnet0,vhost=on,vhostfd=%d \
-device virtio-net-pci,netdev=hostnet0,id=net0,mac=52:54:00:ce:7b:29,bus=pci.0,addr=0x3 \
-monitor stdio", tap_fd, vhost_fd);
```
### Virtio-scsi Performance Data ##

#### The virtio-scsi piecewise patches ##
Paolo's piecewise patches improve performance 2%~4%,
it's really small. [My git tree link.](https://github.com/gaowanlong/linux/commits/vscsi-piece "vscsi-piece branch")

#### The virtio-scsi muti-queue patches ##
Paolo's multi-queue patches improve performance much, almost above 50%.
[My git tree link.](https://github.com/gaowanlong/linux/commits/vscsi-mq "vscsi-mq branch")

#### The virtio-scsi piecewise-mq patches (combined above two) ##
The patches combined piecewise and multi-queue was sent to community for review.
[The email link](http://marc.info/?l=linux-virtualization&m=135583400026151&w=2),
[My git tree link.](https://github.com/gaowanlong/linux/commits/vscsi-piece-mq "vscsi-piece-mq branch")

#### The virtio chained patch ##
Rusty sent out the virtio chained support patch, I rebased against virtio-next
and use it in virtio-scsi, and tested it with 4 targets, virtio-scsi devices
and host cpu idle=poll. Saw a little performance regression here.
[The Email link.](http://marc.info/?l=linux-virtualization&m=135720346214277&w=2)

```
General:
Run status group 0 (all jobs):
   READ: io=34675MB, aggrb=248257KB/s, minb=248257KB/s, maxb=248257KB/s, mint=143025msec, maxt=143025msec
  WRITE: io=34625MB, aggrb=247902KB/s, minb=247902KB/s, maxb=247902KB/s, mint=143025msec, maxt=143025msec

Chained:
Run status group 0 (all jobs):
   READ: io=34863MB, aggrb=242320KB/s, minb=242320KB/s, maxb=242320KB/s, mint=147325msec, maxt=147325msec
  WRITE: io=34437MB, aggrb=239357KB/s, minb=239357KB/s, maxb=239357KB/s, mint=147325msec, maxt=147325msec
```

#### virtio-blk VS. virtio-scsi ##
This data is tested on the upstream virtio-next(3.8.0-rc2).

```
4 targets, host idle=poll.

virtio-blk:
Run status group 0 (all jobs):
   READ: io=35050MB, aggrb=404012KB/s, minb=404012KB/s, maxb=404012KB/s, mint=88838msec, maxt=88838msec
  WRITE: io=34250MB, aggrb=394780KB/s, minb=394780KB/s, maxb=394780KB/s, mint=88838msec, maxt=88838msec

virtio-scsi:
Run status group 0 (all jobs):
   READ: io=34675MB, aggrb=248257KB/s, minb=248257KB/s, maxb=248257KB/s, mint=143025msec, maxt=143025msec
  WRITE: io=34625MB, aggrb=247902KB/s, minb=247902KB/s, maxb=247902KB/s, mint=143025msec, maxt=143025msec
```


#### Work finished ##
Now, the work has already finished by adding the support of multi-queue
virtio-scsi. This patchset flight in the community for a long time,
and went to 3.10-rc1 through the 3.10 merge window. It can almost improve
the performance about 50%. Yes, this is a very good news for virtio-scsi,
and everyone will see the change when 3.10 is released.
The merged patch set is V7: [[PATCH V7 0/5] virtio-scsi multiqueue](http://thread.gmane.org/gmane.linux.kernel.virtualization/19131)

Cheers!!!

---

> Additionally, add a good slide of Asias at KVM FORUM 2012:
>
> [Virtio-blk performance improvement](http://www.linux-kvm.org/images/f/f9/2012-forum-virtio-blk-performance-improvement.pdf)
