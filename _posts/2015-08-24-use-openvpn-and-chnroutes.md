---
layout: post
title: "Use openvpn and chnroutes"
description: ""
category: Linux
tags: [config,vpn]
---


Shadowsocks is not available tonight, it is really a bad news, I should switch
to use openvpn now, and for convenience, add the routes by chnroutes project.

Before use the openvpn client, should get the cert and keys from openvpn server
like, they may look like:

```shell
$ ll
total 24
-rw-r--r-- 1 allen allen 1383 Aug 24 09:45 ca.crt
-rw------- 1 allen allen  916 Aug 24 09:45 ca.key
-rw-r--r-- 1 allen allen 4006 Aug 24 09:45 client1.crt
-rw-r--r-- 1 allen allen  733 Aug 24 09:45 client1.csr
-rw------- 1 allen allen  916 Aug 24 09:45 client1.key
-rw-r--r-- 1 allen allen  251 Aug 24 09:45 vps.ovpn
```

Download the route script from <http://chnroutes-dl.appspot.com>

Add the script to my openvpn configuration file:

```shell
$ chmod +x ip-pre-up ip-down
$ cat >>vps.ovpn <<EOF
script-security 2
up ./ip-pre-up
down ./ip-down
EOF
```

Add new DNS to resolv.conf

```shell
$ cat >/etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 208.67.222.222
EOF
```

And start openvpn:

```shell
$ nohup openvpn vps.ovpn &
```

Instead of downloading the generated scripts, we can also clone the source and
generate by ourselves.

```shell
$ git clone https://github.com/jimmyxu/chnroutes.git
$ cd chnroutes
$ ./chnroutes.py -p linux
```


---

While For macos, can follow the similar steps, but the generated files are ip-up
and ip-down, I write the configuration like following:

```shell
$ cat >>vps.ovpn <<EOF
route-up ip-up
route-pre-down ip-down
EOF
```

The route-up and route-pre-down option is following the manual of Tunnelblick
<https://tunnelblick.net/cUsingScripts.html>
