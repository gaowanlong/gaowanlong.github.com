---
layout: post
title: "Simple analysis of Docker code"
description: ""
category: 
tags: []
---
{% include JB/setup %}

概述
===

花了两天时间阅读一下Docker的代码，顺便学习了Go的语法。没有去仔细研究实现细节，
只对代码结构做了一个大概地梳理。由于是刚接触Go语言, 确实被各种Interface
用Structure来实现搞得有点晕。

Docker的文档写得很好： https://docs.docker.com/

Docker是一个Client/Server架构的用于管理container的工具, 但是它对container
的操作需要借助于更底层的container库来实现，而不是直接去操作cgroupfs, namespace, 
之前我们比较熟知的是LXC, 在Docker 1.10版本之前Docker是以execdriver的形式来支持
使用LXC作为Docker的底层driver, 在1.10版本之后取消了对LXC的支持：
	https://github.com/docker/docker/pull/17700

目前使用的execdriver为libcontainer，也是默认使用的native execdriver,
包含在现在的runc项目里面:
	https://github.com/opencontainers/runc

参与社区
===
以前接触过的社区像linux-kernel等，习惯了用mailing list, 后来接触到openstack
用gerrit，而docker使用的go语言从一开始就深度依赖github, 这一点从打开每一个source
文件一开头的import()就能看出来，类似于：

```go
import (
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/Sirupsen/logrus"
	"github.com/docker/distribution/digest"
	"github.com/docker/docker/api"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/filters"
    ...
    )
```

Docker有详细的关于参与社区的文档:
https://docs.docker.com/opensource/code/

简单来讲就是充分利用了github的开发模式

	create issue => coding => pull request => review => merge

编译
===

docker的编译很简单，从Makefile里面可以看出它是用预先写好的Dockerfile来build一个
用来编译Docker的container, 然后把当前源码COPY到container里面，创建一个bundles
目录以volume的形式挂到container里面，在container里面编译好以后，把编译好的binary
放到挂接的这个volume里面，然后退出，并删除这个container.  所以编译之前首先要
保证编译的system上面有一个可以跑得起来的docker, 然后直接在source的topdir里面
执行"make build && make binary", 退出后bundles目录里面就可以找到编译好的binary.
总体来讲就是**在docker里面编译docker.**

Note:下面提到的代码细节方面的，都是基本docker version:

```shell
	$ git describe 
	v1.4.1-8669-ge9f7241
	$ cat VERSION 
	1.10.0-dev
```

Docker Daemon
===

使用Docker的第一步就是启动Docker的daemon, 使用"docker daemon"子命令. 比如:

	/go/github.com/docker/docker/bundles/1.10.0-dev/binary/docker daemon --storage-driver devicemapper --storage-opt dm.fs=xfs --storage-opt dm.thinpooldev=/dev/mapper/fedora-docker--pool -D

在这里启动docker的时候使用了我自己编译过的docker全路径，这里的thinpooldev是一个
lvm. storage-driver使用的是devicemapper.后面会再介绍一下关于storage driver.
这里用"-D"开启了debug mode,这样可以在daemon端看到一些DEBUG信息，如果对代码不熟悉
也可以借助DEBUG信息来熟悉整个流程。

Docker的Client和Server都由docker这一个binary来完成，这里"docker daemon"会生成
一个监听的http server.

代码可以从docker/docker.go: main()开始，可以dump出一个daemon启动时的callstack
来看看具体流程:

	goroutine 1 [chan receive]:
	main.(*DaemonCli).CmdDaemon(0xc82067a8e0, 0xc82000a140, 0x7, 0x7, 0x0, 0x0)
		/go/src/github.com/docker/docker/docker/daemon.go:277 +0x1c99
	reflect.callMethod(0xc820678840, 0xc820f59c58)
		/usr/local/go/src/reflect/value.go:628 +0x1fc
	reflect.methodValueCall(0xc82000a140, 0x7, 0x7, 0x1, 0xc820678840, 0x0, 0x0, 0xc820678840, 0x0, 0x4733d4, ...)
		/usr/local/go/src/reflect/asm_amd64.s:29 +0x36
	github.com/docker/docker/cli.(*Cli).Run(0xc8206787b0, 0xc82000a130, 0x8, 0x8, 0x0, 0x0)
		/go/src/github.com/docker/docker/cli/cli.go:89 +0x383
	main.main()
		/go/src/github.com/docker/docker/docker/docker.go:63 +0x400

CmdDaemon()启动了apiserver,在CmdDaemon中关注:

	246:	api.InitRouters(d)

它初始化了server中对于client端发来的http请求的处理方法, 比如:
https://github.com/docker/docker/blob/e9f72410ae5c91133a63fbe2d2bd9b36614bc460/api/server/router/container/container.go#L28

		local.NewGetRoute("/containers/json", r.getContainersJSON),

Docker Client
===

Docker Client的作用就是把命令发送给Daemon server去执行，这里用一个最简单的
例子"docker ps --all", 列出当前containers的命令。

当在shell执行这个命令的时候，docker对于它的处理和前面的"docker daemon"是一样
的, "package cli"里面把命令行转换成CmdPs(), 与CmdDaemon()不同的是CmdPs()
等其它命令的处理方法都是由Client端来实现的。

下面我们同样dump出来"docker ps --all"的call stack就很清楚了:

	INFO[0000] === BEGIN goroutine stack dump ===
	goroutine 1 [running]:
	github.com/docker/docker/pkg/signal.DumpStacks()
		/go/src/github.com/docker/docker/pkg/signal/trap.go:67 +0x98
	github.com/docker/docker/api/client/lib.(*Client).newRequest(0xc8202b5ab0, 0x15ba390, 0x3, 0x1696d10, 0x10, 0xc8206a8c90, 0x7f73fa16d4e0, 0xc8202b5b20, 0x0, 0x41d288, ...)
		/go/src/github.com/docker/docker/api/client/lib/request.go:147 +0x35e
	github.com/docker/docker/api/client/lib.(*Client).sendClientRequest(0xc8202b5ab0, 0x15ba390, 0x3, 0x1696d10, 0x10, 0xc8206a8c90, 0x7f73fa16d4e0, 0xc8202b5b20, 0x0, 0x1, ...)
		/go/src/github.com/docker/docker/api/client/lib/request.go:84 +0x28b
	github.com/docker/docker/api/client/lib.(*Client).sendRequest(0xc8202b5ab0, 0x15ba390, 0x3, 0x1696d10, 0x10, 0xc8206a8c90, 0x0, 0x0, 0x0, 0x1f913e0, ...)
		/go/src/github.com/docker/docker/api/client/lib/request.go:70 +0x296
	github.com/docker/docker/api/client/lib.(*Client).get(0xc8202b5ab0, 0x1696d10, 0x10, 0xc8206a8c90, 0x0, 0xb, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/client/lib/request.go:29 +0x86
	github.com/docker/docker/api/client/lib.(*Client).ContainerList(0xc8202b5ab0, 0x10000, 0x0, 0x0, 0x0, 0x0, 0xffffffffffffffff, 0xc8206a8c00, 0x0, 0x0, ...)
		/go/src/github.com/docker/docker/api/client/lib/container_list.go:45 +0x799
	github.com/docker/docker/api/client.(*DockerCli).CmdPs(0xc82024a680, 0xc82000a230, 0x1, 0x1, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/client/ps.go:59 +0xbc3
	reflect.callMethod(0xc8206a8ba0, 0xc8205abc38)
		/usr/local/go/src/reflect/value.go:628 +0x1fc
	reflect.methodValueCall(0xc82000a230, 0x1, 0x1, 0x1, 0xc8206a8ba0, 0x0, 0x0, 0xc8206a8ba0, 0x0, 0x4733d4, ...)
		/usr/local/go/src/reflect/asm_amd64.s:29 +0x36
	github.com/docker/docker/cli.(*Cli).Run(0xc8206a8840, 0xc82000a220, 0x2, 0x2, 0x0, 0x0)
		/go/src/github.com/docker/docker/cli/cli.go:89 +0x383
	main.main()
		/go/src/github.com/docker/docker/docker/docker.go:63 +0x400

上面这是client端的callstack,从main()开始一直到发出请求，很清晰，再结合
Daemon端打印出的DEBUG INFO可以看到client端发出的请求的URL:

	DEBU[0074] Calling GET /v1.22/containers/json
	DEBU[0074] GET /v1.22/containers/json?all=1

这个请求在上面Daemon里面提到过，在api.initRouters(d)的时候注册过:


	local.NewGetRoute("/containers/json", r.getContainersJSON),



因此这个Client的请求会由Server的r.getContainersJSON()来处理, 下面是
它在Daemon里面的callstack:


	INFO[0009] === BEGIN goroutine stack dump ===
	goroutine 37 [running]:
	github.com/docker/docker/pkg/signal.DumpStacks()
		/go/src/github.com/docker/docker/pkg/signal/trap.go:67 +0x98
	github.com/docker/docker/daemon.(*Daemon).transformContainer(0xc820584600, 0xc82093e000, 0xc820d48180, 0xecdca659e, 0x0, 0x0)
		/go/src/github.com/docker/docker/daemon/list.go:391 +0xd13
	github.com/docker/docker/daemon.(*Daemon).(github.com/docker/docker/daemon.transformContainer)-fm(0xc82093e000, 0xc820d48180, 0x0, 0x0, 0x0)
		/go/src/github.com/docker/docker/daemon/list.go:86 +0x42
	github.com/docker/docker/daemon.(*Daemon).reducePsContainer(0xc820584600, 0xc82093e000, 0xc820d48180, 0xc82211f270, 0x0, 0x0, 0x0)
		/go/src/github.com/docker/docker/daemon/list.go:129 +0x116
	github.com/docker/docker/daemon.(*Daemon).reduceContainers(0xc820584600, 0xc820efe0f0, 0xc82211f270, 0x0, 0x0, 0x0, 0x0, 0x0)
		/go/src/github.com/docker/docker/daemon/list.go:99 +0x1a0
	github.com/docker/docker/daemon.(*Daemon).Containers(0xc820584600, 0xc820efe0f0, 0x0, 0x0, 0x0, 0x0, 0x0)
		/go/src/github.com/docker/docker/daemon/list.go:86 +0x6a
	github.com/docker/docker/api/server/router/container.(*containerRouter).getContainersJSON(0xc820b71740, 0x7fdb38b797e8, 0xc820f144b0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000, 0xc820f14180, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/server/router/container/container_routes.go:48 +0x379
	github.com/docker/docker/api/server/router/container.(*containerRouter).(github.com/docker/docker/api/server/router/container.getContainersJSON)-fm(0x7fdb38b797e8, 0xc820f144b0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000, 0xc820f14180, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/server/router/container/container.go:34 +0x74
	github.com/docker/docker/api/server.versionMiddleware.func1(0x7fdb38b797e8, 0xc820f144b0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000, 0xc820f14180, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/server/middleware.go:142 +0x83a
	github.com/docker/docker/api/server.(*Server).corsMiddleware.func1(0x7fdb382f4040, 0xc8200799a0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000, 0xc820f14180, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/server/middleware.go:121 +0xfa
	github.com/docker/docker/api/server.(*Server).userAgentMiddleware.func1(0x7fdb382f4040, 0xc8200799a0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000, 0xc820f14180, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/server/middleware.go:104 +0x4be
	github.com/docker/docker/api/server.debugRequestMiddleware.func1(0x7fdb382f4040, 0xc8200799a0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000, 0xc820f14180, 0x0, 0x0)
		/go/src/github.com/docker/docker/api/server/middleware.go:52 +0x7ca
	github.com/docker/docker/api/server.(*Server).makeHTTPHandler.func1(0x7fdb38b79738, 0xc820e440b0, 0xc820108000)
		/go/src/github.com/docker/docker/api/server/server.go:168 +0x354
	net/http.HandlerFunc.ServeHTTP(0xc820bfa0c0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000)
		/usr/local/go/src/net/http/server.go:1422 +0x3a
	github.com/gorilla/mux.(*Router).ServeHTTP(0xc820c34000, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000)
		/go/src/github.com/docker/docker/vendor/src/github.com/gorilla/mux/mux.go:98 +0x29e
	net/http.serverHandler.ServeHTTP(0xc82026e7e0, 0x7fdb38b79738, 0xc820e440b0, 0xc820108000)
		/usr/local/go/src/net/http/server.go:1862 +0x19e
	net/http.(*conn).serve(0xc820e44000)
		/usr/local/go/src/net/http/server.go:1361 +0xbee
	created by net/http.(*Server).Serve
		/usr/local/go/src/net/http/server.go:1910 +0x3f6


Storage Driver
===

Docker里面目前支持的Storage Driver有：
https://github.com/docker/docker/blob/e9f72410ae5c91133a63fbe2d2bd9b36614bc460/daemon/graphdriver/driver_linux.go#L47  


	// Slice of drivers that should be used in an order
	priority = []string{
		"aufs",
		"btrfs",
		"zfs",
		"devicemapper",
		"overlay",
		"vfs",
	}


从一开始docker是基于AUFS，但是AUFS进不了upstream, redhat又不能用它，就自己基于devicemapper
重新开发了一个backend. overlayfs由于速度很快，可以共享page cache等优点，而它union fs的特性
也正好符合docker的需求，因此也被添加了进来。对于这些storage driver的综合对比，RedHat有一篇blog
分析得很好: [Comprehensive Overview of Storage Scalability in Docker
](http://developerblog.redhat.com/2014/09/30/overview-storage-scalability-docker/)


