---
layout: post
title: "How to reload an USB storage media after it is ejected"
description: ""
category: Linux
tags: [USB, Linux, eject]
---
{% include JB/setup %}

When an USB storage media is plugged in, the system will detect
it automatically, and automount it in some modern Linux releases.

Then if we want to unplug it, we may umount it first and eject
it using /bin/eject command which is provided in util-linux package.

Yes, we can also eject it using the gnome interface by just click
a "eject botton". This action may be handled by udisks2->dbus, I
am not sure, but this is not what we are talking about here.

For example, we plug an USB storage media into the machine, and
this USB storage device is detected to "/dev/sdd", and this has
one partition "/dev/sdd1", the system will mount "/dev/sdd1" to
some mount point. Then we umount "/dev/sdd1" by hand, and use
"/bin/eject" command to eject this USB storage media:

	# /bin/eject -s /dev/sdd

Then we can see that this device is ejected by list "/dev/sdd1".
We can see that "/dev/sdd1" is disappeared, just remain "/dev/sdd" now,
and the "dmesg" shows that the media is really ejected:

	sdd: detected capacity change from 15518924800 to 0

While, now we can unplug this USB storage device and replug it, the system
can detect it automatically again and automount it.

While, can we let system reload this USB storage media by not replugging
this device physically? I think the answer must be yes, so I read some
code of "/bin/eject" to find out it.

Here is the source code piece of "/bin/eject":

	/*
	 * Eject using SCSI SG_IO commands. Return 1 if successful, 0 otherwise.
	 */
	static int eject_scsi(int fd)
	{
		int status, k;
		sg_io_hdr_t io_hdr;
		unsigned char allowRmBlk[6] = {ALLOW_MEDIUM_REMOVAL, 0, 0, 0, 0, 0};
		unsigned char startStop1Blk[6] = {START_STOP, 0, 0, 0, 1, 0};
		unsigned char startStop2Blk[6] = {START_STOP, 0, 0, 0, 2, 0};
		unsigned char inqBuff[2];
		unsigned char sense_buffer[32];
	
		if ((ioctl(fd, SG_GET_VERSION_NUM, &k) < 0) || (k < 30000)) {
			verbose(_("not an sg device, or old sg driver"));
			return 0;
		}
	
		memset(&io_hdr, 0, sizeof(sg_io_hdr_t));
		io_hdr.interface_id = 'S';
		io_hdr.cmd_len = 6;
		io_hdr.mx_sb_len = sizeof(sense_buffer);
		io_hdr.dxfer_direction = SG_DXFER_NONE;
		io_hdr.dxfer_len = 0;
		io_hdr.dxferp = inqBuff;
		io_hdr.sbp = sense_buffer;
		io_hdr.timeout = 10000;
	
		io_hdr.cmdp = allowRmBlk;
		status = ioctl(fd, SG_IO, (void *)&io_hdr);
		if (status < 0 || io_hdr.host_status || io_hdr.driver_status)
			return 0;
	
		io_hdr.cmdp = startStop1Blk;
		status = ioctl(fd, SG_IO, (void *)&io_hdr);
		if (status < 0 || io_hdr.host_status)
			return 0;
	
		/* Ignore errors when there is not medium -- in this case driver sense
		 * buffer sets MEDIUM NOT PRESENT (3a) bit. For more details see:
		 * http://www.tldp.org/HOWTO/archived/SCSI-Programming-HOWTO/SCSI-Programming-HOWTO-22.html#sec-sensecodes
		 * -- kzak Jun 2013
		 */
		if (io_hdr.driver_status != 0 &&
		    !(io_hdr.driver_status == DRIVER_SENSE && io_hdr.sbp &&
			                                      io_hdr.sbp[12] == 0x3a))
			return 0;
	
		io_hdr.cmdp = startStop2Blk;
		status = ioctl(fd, SG_IO, (void *)&io_hdr);
		if (status < 0 || io_hdr.host_status || io_hdr.driver_status)
			return 0;
	
		/* force kernel to reread partition table when new disc inserted */
		ioctl(fd, BLKRRPART);
		return 1;
	}

This line:

	status = ioctl(fd, SG_IO, (void *)&io_hdr);

We can see that this command use a "SG_IO ioctl()" to this block device.
After reading the kernel source, I knew that "SG_IO ioctl()" is used to send
SCSI command to the SCSI device. Yes, this USB storage is treated as a SCSI
device.

Now, we can analyze what is included in the argument "io_hdr":

		io_hdr.interface_id = 'S';
		io_hdr.cmd_len = 6;
		io_hdr.mx_sb_len = sizeof(sense_buffer);
		io_hdr.dxfer_direction = SG_DXFER_NONE;
		io_hdr.dxfer_len = 0;
		io_hdr.dxferp = inqBuff;
		io_hdr.sbp = sense_buffer;
		io_hdr.timeout = 10000;

See above, the most important data here is "io_hdr.interface_id = 'S'",
it means that this is a general SCSI command. Others are much easy to
understand.

The real most important data is "io_hdr.cmdp", we can see three "cmdp"
in the above code:

	io_hdr.cmdp = allowRmBlk;
	io_hdr.cmdp = startStop1Blk;
	io_hdr.cmdp = startStop2Blk;

They are mostly the same, but the real "eject cmdp" here is "startStop2Blk",
we can see this data:

	unsigned char startStop2Blk[6] = {START_STOP, 0, 0, 0, 2, 0};

Why? Send this data to device can eject it? Let us read the SCSI command SPEC:

![star_stop_1](/images/2013-09-13-1.png)
![star_stop_2](/images/2013-09-13-2.png)

We are aiming at the 0bit and 1bit of 4Byte in this command. The 4Byte of "startStop2Blk"
is "2", it indicates that the "LOEJ" bit is "1" and "START" bit is "0". Refer to the
SPEC we can see "If the LOEJ bit is set to one, then the logical unit shall unload the
medium if the START bit is set to zero." Yeah, that the thing, we find out why this
command can eject the USB storage media.

The SPEC also said that "If the LOEJ bit is set to one, then the logical unit shall
load the medium if the START bit is set to one." We know that if the 0bit and 1bit
are both set to "1", means the 4Byte is "3", the USB storage media can be reloaded.

It is clear now, we can make a new data:

	unsigned char startStop3Blk[6] = {START_STOP, 0, 0, 0, 3, 0};

And send this new "cmdp" to the USB device using "SG_IO ioctl()", the USB storage
media will be present to us again. Cheers!

PS: there is already a command can do this for us, it is "sg_start":

	# sg_start --load /dev/sdd
