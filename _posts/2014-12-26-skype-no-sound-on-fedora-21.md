---
layout: post
title: "skype no sound on Fedora 21 x86_64"
description: ""
category: Linux
tags: [skype]
---


Skype on Feodra 21 using lpf-skype install method,
after install, there is no sound on x86_64 bit system.
Because the i686 dependent libs is not installed yet.

Check that if the below libs is installed on x86_64 system.

	yum install libv4l.i686 pulseaudio-libs.i686 alsa-plugins-pulseaudio.i686
