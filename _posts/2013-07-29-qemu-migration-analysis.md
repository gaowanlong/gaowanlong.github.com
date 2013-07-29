---
layout: post
title: "QEMU migration analysis"
description: "QEMU migration"
category: 
tags: [qemu, migration]
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
