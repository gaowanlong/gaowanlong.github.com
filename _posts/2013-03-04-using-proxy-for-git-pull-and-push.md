---
layout: post
title: "Using proxy for git pull and push"
description: ""
category: Linux
tags: [git]
---

### Use git proxy on git protocol ##
git protocol is read only for git, so we can just clone/pull
git repo using this protocol. It is git:// like.
We are using core.gitproxy feature here.
Firstly, insert the config to your gitconfig file, whether for
global or not. config like this:

```ini
[core]
	gitproxy = gitproxy-command
```
Then, we should create the gitproxy-command by ourselves.
For example(the proxy is 10.167.1.1:8080):

```shell
$ cat /usr/bin/gitproxy-command
#!/bin/bash
PROXY=10.167.1.1
PROXYPORT=8080
exec socat STDIO PROXY:$PROXY:$1:$2,proxyport=$PROXYPORT
```

The socat tool used in above command line can be found here:[http://www.dest-unreach.org/socat/]( http://www.dest-unreach.org/socat/)


### proxy for git send-email

proxy is useful for us, especially for git send-email by gmail. The msmtp can
set proxy in the *.msmtprc* config file like:

```
# gmail
account gmail
host smtp.gmail.com
port 587
proxy_host 127.0.0.1
proxy_port 1080
from wanlong.gao@gmail.com
auth on
user wanlong.gao@gmail.com
password xxx
```
Then we can use *git send-email* with *msmtp* server:

```
git send-email --smtp-server /usr/bin/msmtp xxx.patch
```
