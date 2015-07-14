---
layout: post
title: "QEMU migration analysis"
description: "QEMU migration"
category: virtualization
tags: [qemu]
---
{% include JB/setup %}

## MEMO#

### outgoing migration ##
    migrate_fd_connect()
     |-->migrate_thread()
          |-->qemu_savevm_state_begin()
          |-->qemu_savevm_state_pending()
          |-->qemu_savevm_state_iterate()
          |-->qemu_savevm_state_complete()


### incoming migration ##
    qemu_start_incoming_migration()
     |-->tcp_start_incoming_migration()
          |-->tcp_accept_incoming_migration()
               |-->process_incoming_migration()
                    |-->process_incoming_migration_co() (coroutine)
                         |-->qemu_loadvm_state()
                         |-->qemu_announce_self()
                         |-->bdrv_clear_incoming_migration_all()
                         |-->bdrv_invalidate_cache_all()
