---
layout: post
title: "The rbd-backed storage of nova"
description: ""
category: Virtualization
tags: []
---

RBD LAYERING
============
(http://docs.ceph.com/docs/master/dev/rbd-layering/)
顾名思义，比如ceph里有一个base image，我们要clone到一个新的instance里，做法
分两步:

* 先给这个base image创建一个快照

* 对这个快照进行clone

快照在clone之前要设成protect状态

如果这个快照被clone了，那么在child没有被删除或者没有进行flatten操作之前,
这个快照的protect状态是取消不掉的，因此它不会被删除。只有它的children都
被删除或flatten以后(也即不再被依赖)，它才可以被删除。

Clone
====


