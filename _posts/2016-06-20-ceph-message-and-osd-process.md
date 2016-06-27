---
layout: post
title: "ceph message and osd process"
description: ""
category: Storage
tags: [ceph]
---

OSD message queue
================


Pipe读到的能走fast dispatch的直接走fast dispatch, 不能走fast的queue起来
交给dispatch_thread处理

```cpp
void Pipe::start_reader()
-> void Pipe::reader()
        if (in_q->can_fast_dispatch(m)) {
          in_q->fast_dispatch(m);
        } else {
          in_q->enqueue(m, m->get_priority(), conn_id);
	}
```

创建的两个thread一个用来处理queue里的请求，一个用来处理local请求

```cpp
void DispatchQueue::start()
->dispatch_thread.create("ms_dispatch");
  local_delivery_thread.create("ms_local");
```

```cpp
dispatch_thread.create("ms_dispatch");
-> void DispatchQueue::entry()
      msgr->ms_deliver_dispatch(m);
-> Messenger:: void ms_deliver_dispatch(Message *m)
-> bool OSD::ms_dispatch(Message *m)
-> void OSD::_dispatch(Message *m)
    handle_osd_map(static_cast<MOSDMap*>(m));
    handle_command(static_cast<MMonCommand*>(m));
    handle_scrub(static_cast<MOSDScrub*>(m));
    ...
    dispatch_op(op);
-> void OSD::dispatch_op(OpRequestRef op)
```


local_delivery_thread用来处理本地请求，同样能走fast的直接走fast，不能走fast
的queue起来，dispatch_thread来处理.
local_delivery_thread处理的请求是在submit_message的时候，如果判断是local请求
通过local_delivery放到local_messages里

```cpp
local_delivery_thread.create("ms_local");
-> void DispatchQueue::run_local_delivery()
-> void DispatchQueue::fast_dispatch(Message *m)
-> Messenger::  void ms_fast_dispatch(Message *m) {
-> void OSD::ms_fast_dispatch(Message *m)
-> void OSD::dispatch_session_waiting(Session *session, OSDMapRef osdmap)
-> bool OSD::dispatch_op_fast(OpRequestRef& op, OSDMapRef& osdmap)
```


OSD r/w message process
=======================

```cpp

=> void ShardedThreadPool::start()
-> void ShardedThreadPool::start_threads()
-> ShardedThreadPool::WorkThreadSharded::entry()
-> void ShardedThreadPool::shardedthreadpool_worker(uint32_t thread_index)
-> void OSD::ShardedOpWQ::_process(uint32_t thread_index, heartbeat_handle_d *hb )
-> void PGQueueable::RunVis::operator()(const OpRequestRef &op) {
-> void OSD::dequeue_op
-> void ReplicatedPG::do_request
-> void ReplicatedPG::do_op(OpRequestRef& op)
-> void ReplicatedPG::execute_ctx(OpContext *ctx)
```
