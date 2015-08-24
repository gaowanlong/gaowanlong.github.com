---
layout: post
title: "Use openvpn and chnroutes"
description: ""
category: 
tags: []
---
{% include JB/setup %}


Shadowsocks is not available tonight, it is really a bad news, I should switch
to use openvpn now, and for convenience, add the routes by chnroutes project.

Before use the openvpn client, should get the cert and keys from openvpn server
like, they may look like:

	$ ll
	total 24
	-rw-r--r-- 1 allen allen 1383 Aug 24 09:45 ca.crt
	-rw------- 1 allen allen  916 Aug 24 09:45 ca.key
	-rw-r--r-- 1 allen allen 4006 Aug 24 09:45 client1.crt
	-rw-r--r-- 1 allen allen  733 Aug 24 09:45 client1.csr
	-rw------- 1 allen allen  916 Aug 24 09:45 client1.key
	-rw-r--r-- 1 allen allen  251 Aug 24 09:45 vps.ovpn

Download the route script from <http://chnroutes-dl.appspot.com>

Add the script to my openvpn configuration file:

	chmod +x ip-pre-up ip-down
	cat >>vps.ovpn <<EOF
	script-security 2
	up ./ip-pre-up
	down ./ip-down
	EOF

Add new DNS to resolv.conf

	cat >/etc/resolv.conf <<EOF
	nameserver 8.8.8.8
	nameserver 8.8.4.4
	nameserver 208.67.222.222
	EOF

And start openvpn:

	nohup openvpn vps.ovpn &
