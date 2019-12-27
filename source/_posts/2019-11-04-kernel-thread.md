---
title: linux多线程
date: 2019-11-04
categories: develop 
author: yawei.zhang 
---

### ..1. 多线程    

1. 老的LinuxThreads (管理线程机制) 设计中线程栈的位置在 HEAP之下 的高位 导致无法可信的设置heap大小  
2.  新的NPTL解决了老的线程机制中的管理单点问题 信号问题 内存布局问题等 顺便实现了PTHREAD_PROCESS_SHARED 
3.  pthread_attr_setstackaddr可指定线程栈的地址(mmap)   
4.  pthread的创建和销毁 
    1.  创建   
        1. 使用用户提供的stack创建线程并加入__stack_user 
        2. nptl 先尝试获取stack_cache中tid为0大小合适的空闲stack, 如果失败则从mmap分配新的stack, 然后加入stack_used  
        3. tid list等信息存储在stack内存的高地址端的头部  
    2.  start_thread执行完用户函数后会进行数据回收和清理(但无法销毁自身)   
        1. 如果该线程非detach 则等待join  (没有join则会一直保留)  
        2. 如果该线程被detach 则执行__free_tcb   
            1. 如果是用户分配的stack 从stack_user链表中移除并清理tls 线程局部存储  
            2. 如果是自动分配的stack 从stack_used链表中移除, 然后加入stack_cache中, 清理tls线程局部存储(此时tid不为0)   
            3. 检查当前stack_cache的总大小, 超过阈值则遍历一次stack_cache并释放掉(tid为0)空闲的stack, 如果小于阈值则提前break该次遍历   
    3. 内核在该线程结束后 会对该线程的tid清零(创建线程时CLONE_CHILD_CLEARTID参数会让内存清除某标记内存), 此后该资源可以安全销毁.        
5.  brk和mmap的分配由glibc确定 默认规则是小于M_MMAP_THRESHOLD宏走brk  但是新系统的算法可能会让大于这个参数的临时分配也走brk   
<!-- more --> 



### Linux 发行版所使用的线程模型、glibc 版本和内核版本    

cat /proc/version                查看内核版本   
getconf GNU_LIBPTHREAD_VERSION   查看线程模型
| 线程实现          | C 库     ---------            | 发行版                           | 内核   |
|-------------------|-------------------------------|----------------------------------|--------|
| LinuxThreads 0.7  | 0.71 (for libc5)  libc 5.x    | Red Hat 4.2                      |
| LinuxThreads 0.7  | 0.71 (for glibc 2) glibc 2.0. | Red Hat 5.x                      |
| LinuxThreads 0.8  | glibc 2.1.1                   | Red Hat 6.0                      |
| LinuxThreads 0.8  | glibc 2.1.2                   | Red Hat 6.1 and 6.2              |
| LinuxThreads 0.9  |                               | Red Hat 7.2                      | 2.4.7  |
| LinuxThreads 0.9  | glibc 2.2.4                   | Red Hat 2.1 AS                   | 2.4.9  |
| LinuxThreads 0.10 | glibc 2.2.93                  | Red Hat 8.0                      | 2.4.18 |
| NPTL 0.6          | glibc 2.3                     | Red Hat 9.0                      | 2.4.20 |
| NPTL 0.61         | glibc 2.3.2                   | Red Hat 3.0 EL                   | 2.4.21 |
| NPTL 2.3.4        | glibc 2.3.4                   | Red Hat 4.0                      | 2.6.9  |
| LinuxThreads 0.9  | glibc 2.2                     | SUSE Linux Enterprise Server 7.1 | 2.4.18 |
| LinuxThreads 0.9  | glibc 2.2.5                   | SUSE Linux Enterprise Server 8   | 2.4.21 |
| LinuxThreads 0.9  | glibc 2.2.5                   | United Linux                     | 2.4.21 |
| NPTL 2.3.5        | glibc 2.3.3                   | SUSE Linux Enterprise Server 9   | 2.6.5  |