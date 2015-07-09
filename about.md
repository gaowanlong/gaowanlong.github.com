---
layout: page
title: "About"
description: "More information about me"
group: navigation
---
{% include JB/setup %}


Lazily fetched the resume to write this page: (in vim)

	:r !wget -O - https://github.com/gaowanlong/resume/raw/master/resume.md 2>/dev/null

The PDF version can be found by [Click Here](https://github.com/gaowanlong/resume/raw/master/resume.pdf).

---

Resume
======

Name: Wanlong Gao  
Email: [wanlong.gao@gmail.com](mailto:wanlong.gao@gmail.com)  
Github: [gaowanlong](https://github.com/gaowanlong)  
Blog: [blog.allenx.org](http://blog.allenx.org)  
Handset: XXXXXXXXXXX


Interests
---------

*   Read Linux related paper (kernel, virtualization and storage)
*   Chinese Calligraphy

Work Experience
---------------

*   **Linux Kernel Developer** (Fujitsu, 2011.07~present)

    *0day/LKP+(Linux Kernel Performance)*

    - Main developer and the sub-maintainer

    - Fix daily bugs and develop new features(like multi-node framework)

    - Find and add the useful benchmarks to our framework

    *Linux Virtualization*

    - Implement the virtqueue affinity for virtio-net and virtio-scsi, which
      improve the performance of them, especially after doing cpu hotplug

    - Help implement the virtio-scsi multi-queue feature, which can improve
      the performance of virtio-scsi about 30%

    - Help review some virtio related patches

    - Implement the NUMA binding of QEMU to improve the performance of cross
      node qemu-kvm guest

    - Add many new APIs, features and fix many bugs of libguestfs

    - Fix bugs of virt-clone tool

    - Co-author of the virt-sysprep tool


    *LTP(Linux Test Project)*

    - Co-maintainer of LTP, review and commit a part of patches in community

    - Report and fix bugs found by LTP on RedHat Enterprise Linux

    - Report and fix upstream Linux Kernel bugs which found by LTP

    - Fix the bugs of LTP to improve the quality of test cases

    - Add new test cases to improve the coverage of LTP


*   **Linux Driver Developer** (Hisense, 2010.07~2011.06)

    *Linux Power managemant and input subsystem driver*

    - Develop and maintain android smartphone power charger driver

    - Develop and maintain android smartphone keypad and touchpad driver

    - Reviewed many upstream input subsystem patches

    - Wrote the device driver-model kerneldoc for upstream kernel


Open Source Contribution
-----------------------

*   *Linux Kernel contribution:*

    <http://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/log/?qt=grep&q=Wanlong>

*   *Libguestfs contribution:*

    <https://github.com/libguestfs/libguestfs/commits/master?author=gaowanlong>

*   *LKP+(Linux Kernel Performance) contribution:* (only partly opensourced)

    <https://git.kernel.org/cgit/linux/kernel/git/wfg/lkp-tests.git/log/?qt=grep&q=Wanlong>

*   *LTP(Linux Test Project) contribution:*

    <https://github.com/linux-test-project/ltp/commits/master?author=gaowanlong>

*   *QEMU contribution:*

    NUMA binding patches: <https://lists.gnu.org/archive/html/qemu-devel/2013-12/msg00568.html>

    <http://git.qemu.org/?p=qemu.git&a=search&h=HEAD&st=commit&s=Wanlong>

*   *virt-clone contribution:*

    <https://git.fedorahosted.org/cgit/python-virtinst.git/log/?qt=grep&q=Wanlong>


Education
---------

*   **Northeastern University** (2006~2010, Bachelor)


Skills
------

*   Many years of Linux administrator and development experience (since 2008)

*   Good knowledge and experience of Linux Kernel and Virtualization

*   Good knowledge and experience of writing code in C, shell, ruby

*   Can write code in any languages after one day learning :)
