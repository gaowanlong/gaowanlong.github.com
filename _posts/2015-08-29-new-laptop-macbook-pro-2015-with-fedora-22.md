---
layout: post
title: "New laptop macbook pro 2015 with Fedora 22"
description: ""
category: Linux
tags: []
---
{% include JB/setup %}

I got a Macbook Pro 2015 recently, and it seems necessary to install a Linux
since I should do kernel work on it. Otherwise, I can use the default macos
with a virtual machine. So I determine to install a multi-boot both macos and
Fedora 22.

Boot into macos and setup the partition, gave half space to Fedora 22.

Make a USB boot disk by just *dd* the Fedora 22 workstation iso to USB disk.

Reboot machine with the *option* key pressed, choose to boot from the USB disk,
then will go into the general Fedora install steps. Just follow the general
install steps, but note that use the EFI, and create a */boot/efi* partition.

Do some configuration after install finished.

* The default kernel of Fedora 22 is v4.0 and can be updated to v4.1, but the
  touchpad is a bit new and the driver was just merged to the upstream kernel
  from v4.2-rc2:

		$ git describe  dbe08116b87cdc2217f11a78b5b70e29068b7efd
		v4.2-rc4-107-gdbe0811

  As you can see, the official Fedora 22 kernel can not support the bcm5974
  input device. So I compiled the latest release v4.2-rc8 and the Touchpad and
  some function keys can work now.

* After above kernel driver support, can find that the Touchpad can still not
  support the Tap-to-click function. It is a very useful function for me because
  I do not like click so much. After google search, I find that from Fedora 22,
  *libinput* is used as the default xorg driver instead of evdev and synaptics
  driver, this is the original mail URL:
  <https://lists.fedoraproject.org/pipermail/devel/2015-February/208204.html>.
  And the right method to enable the Tap-to-click function and use the *xinput*
  tool:

		[root@fedora ~]# xinput list
		⎡ Virtual core pointer                    	id=2	[master pointer  (3)]
		⎜   ↳ Virtual core XTEST pointer              	id=4	[slave  pointer  (2)]
		⎜   ↳ Broadcom Corp. Bluetooth USB Host Controller	id=11	[slave  pointer  (2)]
		⎜   ↳ bcm5974                                 	id=13	[slave  pointer  (2)]
		⎣ Virtual core keyboard                   	id=3	[master keyboard (2)]
		    ↳ Virtual core XTEST keyboard             	id=5	[slave  keyboard (3)]
		    ↳ Power Button                            	id=6	[slave  keyboard (3)]
		    ↳ Video Bus                               	id=7	[slave  keyboard (3)]
		    ↳ Power Button                            	id=8	[slave  keyboard (3)]
		    ↳ Sleep Button                            	id=9	[slave  keyboard (3)]
		    ↳ Broadcom Corp. Bluetooth USB Host Controller	id=10	[slave  keyboard (3)]
		    ↳ Apple Inc. Apple Internal Keyboard / Trackpad	id=12	[slave  keyboard (3)]
		[root@fedora ~]# xinput list-props 13
		Device 'bcm5974':
			Device Enabled (136):	1
			Coordinate Transformation Matrix (138):	1.000000, 0.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, 1.000000
			libinput Tapping Enabled (282):	1
			libinput Tapping Enabled Default (283):	0
			libinput Tapping Drag Lock Enabled (284):	0
			libinput Tapping Drag Lock Enabled Default (285):	0
			libinput Accel Speed (269):	0.000000
			libinput Accel Speed Default (270):	0.000000
			libinput Natural Scrolling Enabled (271):	0
			libinput Natural Scrolling Enabled Default (272):	0
			libinput Send Events Modes Available (254):	1, 1
			libinput Send Events Mode Enabled (255):	0, 0
			libinput Send Events Mode Enabled Default (256):	0, 0
			libinput Left Handed Enabled (273):	0
			libinput Left Handed Enabled Default (274):	0
			libinput Scroll Methods Available (275):	1, 1, 0
			libinput Scroll Method Enabled (276):	1, 0, 0
			libinput Scroll Method Enabled Default (277):	1, 0, 0
			libinput Click Methods Available (286):	1, 1
			libinput Click Method Enabled (287):	0, 1
			libinput Click Method Enabled efault (288):	0, 1
			libinput Disable While Typing Enabled (289):	1
			libinput Disable While Typing Enabled Default (290):	1
			Device Node (257):	"/dev/input/event8"
			Device Product ID (258):	1452, 627
		[root@fedora ~]# xinput set-prop 13 282 1

  The number *13* and *282* in above command is the id of device and libinput Tapping
  Enabled event. After this, tap to touchpad should already be recognized to
  click event.

  Then the following script can do the above things:

		#!/bin/bash

		id=$(xinput list | grep bcm5974 | awk '{print $4}'| cut -d= -f2)
		echo $id
		prop=$(xinput list-props $id | grep "Tapping Enabled (")
		echo $prop
		prop=${prop##*(}
		echo $prop
		prop=${prop%%)*}
		echo $prop
		xinput set-prop $id $prop 1


* My hand is familiar with the HHKB keyboard layout, so the normal keyboard
  layout is not suitable for me, I should swap some keys, use *gnome-tweak-tool*
  to swap some function key is very convenient and I use it to set the *CapsLock*
  act as *Contrl* and swap the *Option* and *Command* key. The use *xmodmap*
  tool to swap other not function keys like:

		# back up the original map
		$ xmodmap -pke > key_orig
		# following keycode can be found from the tool *xev | grep key*
		$ cat >key_change <<EOF
		keycode 9 = grave asciitilde grave asciitilde
		keycode 94 = Escape NoSymbol Escape
		keycode 51 = BackSpace
		keycode 22 = backslash bar backslash bar
		EOF
		$ xmodmap key_change

* Then my vim editor, I always use the Vundle <https://github.com/gmarik/Vundle.vim.git>
  to manage my plugins, it is powerful and easy to use.

---

* Modify the PS1 with colors. Side note about the colors: The colors are preceded
  by an escape sequence \e and defined by a color value, composed of [style;color+m]
  and wrapped in an escaped [] sequence. eg.

		$ cat >~/.bash_profile <<EOF
		export PS1='\[\e[0;31m\]\u\[\e[0m\]@\[\e[0;32m\]mac\[\e[0m\]: \[\e[0;35m\]\w\[\e[0m\] \$ '
		alias ls='ls -G'
		alias ll='ls -l'
		alias grep='grep --color'
		EOF

		red= \[\e[0;31m\]
		bold red (style 1) = \[\e[1;3m\]
		clear coloring = \[\e[0m\]

		My favor PS1:

		/root/.bashrc:
		export PS1='\[\e[1;31m\]\u\[\e[0m\]@\[\e[1;31m\]ROOT\[\e[0m\]: \[\e[0;35m\]\w\[\e[0m\] \$ '

		/home/$USER/.bashrc:
		export PS1='\[\e[1;31m\]\u\[\e[0m\]@\[\e[1;32m\]home\[\e[0m\]: \[\e[1;35m\]\w\[\e[0m\] \$ '

* switch the ruby gem source before install jekyll, since the official one is too slow:

		$ gem sources --remove https://rubygems.org/
		$ gem sources --remove http://rubygems.org/
		$ gem sources -a http://ruby.taobao.org/
		$ gem sources -l
		*** CURRENT SOURCES ***

		http://ruby.taobao.org

