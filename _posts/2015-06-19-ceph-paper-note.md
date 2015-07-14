---
layout: post
title: "Ceph paper note"
description: ""
category: linux
tags: [ceph]
---
{% include JB/setup %}

###Three main components:

- clients, expose near-POSIX file system interface to host or process
- cluster of OSDs, store data and metadata
- metadata server cluster, manage the namespace

###Ceph address the scalability issue through three features:

- Decoupled data and Metadata

  Metadata operations are managed by a metadata server while clients interact
  directly with OSDs to perform file I/O.

- Dynamicl distributed metadata management

  Cluster architecture based on Dynamic Subtree Partitioning.
  Manage file system directory hierarchy among tens or even hundreds of MDSs.

- Reliable autonomic distributed object storage.

  Design for device failures are frequent and expected.
