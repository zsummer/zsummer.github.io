
---
title: MEMORY OVERCOMMIT     
date: 2021-11-15
categories: develop 
author: yawei.zhang 
mathjax: false
---


Memory Overcommit的意思是操作系统承诺给进程的内存大小超过了实际可用的内存.    
一个保守的操作系统不会允许memory overcommit, 有多少就分配多少, 再申请就没有了, 这其实有些浪费内存, 因为进程实际使用到的内存往往比申请的内存要少  
比如某个进程malloc()了200MB内存, 但实际上只用到了100MB, 按照UNIX/Linux的算法, 物理内存页的分配发生在使用的瞬间, 而不是在申请的瞬间, 也就是说未用到的100MB内存根本就没有分配, 这100MB内存就闲置了   
下面这个概念很重要, 是理解memory overcommit的关键:  **commit(或overcommit)针对的是内存申请, 内存申请不等于内存分配, 内存只在实际用到的时候才分配.  **      

<!-- more -->

Linux是允许memory overcommit的, 只要你来申请内存我就给你, 寄希望于进程实际上用不到那么多内存, 但万一用到那么多了呢？那就会发生类似“银行挤兑”的危机, 现金(内存)不足了.    
Linux设计了一个OOM killer机制(OOM = out-of-memory)来处理这种危机:  挑选一个进程出来杀死, 以腾出部分内存, 如果还不够就继续杀…也可通过设置内核参数 vm.panic_on_oom 使得发生OOM时自动重启系统.     
这都是有风险的机制, 重启有可能造成业务中断, 杀死进程也有可能导致业务中断, Linux 2.6之后允许通过内核参数 vm.overcommit_memory 禁止memory overcommit.  



内核参数 vm.overcommit_memory 接受三种取值:     

* 0 – Heuristic overcommit handling. 这是缺省值, 它允许overcommit, 但过于明目张胆的overcommit会被拒绝, 比如malloc一次性申请的内存大小就超过了系统总内存.  Heuristic的意思是“试探式的”, 内核利用某种算法（对该算法的详细解释请看文末）猜测你的内存申请是否合理, 它认为不合理就会拒绝overcommit.     
* 1 – Always overcommit. 允许overcommit, 对内存申请来者不拒.     
* 2 – Don’t overcommit. 禁止overcommit.     



关于禁止overcommit (vm.overcommit_memory=2) , 需要知道的是, 怎样才算是overcommit呢？kernel设有一个阈值, 申请的内存总数超过这个阈值就算overcommit, 在/proc/meminfo中可以看到这个阈值的大小:    
```
# grep -i commit /proc/meminfo
CommitLimit:     5967744 kB
Committed_AS:    5363236 kB
```

CommitLimit 就是overcommit的阈值, 申请的内存总数超过CommitLimit的话就算是overcommit.  
这个阈值是如何计算出来的呢？它既不是物理内存的大小, 也不是free memory的大小, 它是通过内核参数vm.overcommit_ratio或vm.overcommit_kbytes间接设置的, 公式如下:  
```CommitLimit = (Physical RAM * vm.overcommit_ratio / 100) + Swap```

注:  
vm.overcommit_ratio 是内核参数, 缺省值是50, 表示物理内存的50%.  如果你不想使用比率, 也可以直接指定内存的字节数大小, 通过另一个内核参数 vm.overcommit_kbytes 即可; 
如果使用了huge pages, 那么需要从物理内存中减去, 公式变成:  
CommitLimit = ([total RAM] – [total huge TLB RAM]) * vm.overcommit_ratio / 100 + swap
参见https://access.redhat.com/solutions/665023

/proc/meminfo中的 Committed_AS 表示所有进程已经申请的内存总大小, （注意是已经申请的, 不是已经分配的）, 如果 Committed_AS 超过 CommitLimit 就表示发生了 overcommit, 超出越多表示 overcommit 越严重.  Committed_AS 的含义换一种说法就是, 如果要绝对保证不发生OOM (out of memory) 需要多少物理内存.  

“sar -r”是查看内存使用状况的常用工具, 它的输出结果中有两个与overcommit有关, kbcommit 和 %commit:  
kbcommit对应/proc/meminfo中的 Committed_AS; 
%commit的计算公式并没有采用 CommitLimit作分母, 而是Committed_AS/(MemTotal+SwapTotal), 意思是_内存申请_占_物理内存与交换区之和_的百分比.  

```
$ sar -r 
 
05:00:01 PM kbmemfree kbmemused  %memused kbbuffers  kbcached  kbcommit   %commit  kbactive   kbinact   kbdirty
05:10:01 PM    160576   3648460     95.78         0   1846212   4939368     62.74   1390292   1854880         4
```


## 附:  对Heuristic overcommit算法的解释  
内核参数 vm.overcommit_memory 的值0, 1, 2对应的源代码如下, 其中heuristic overcommit对应的是OVERCOMMIT_GUESS:  
```C++
源文件:  source/include/linux/mman.h
#define OVERCOMMIT_GUESS                0
#define OVERCOMMIT_ALWAYS               1
#define OVERCOMMIT_NEVER                2
```

Heuristic overcommit算法在以下函数中实现, 基本上可以这么理解:  
单次申请的内存大小不能超过 【free memory + free swap + pagecache的大小 + SLAB中可回收的部分】, 否则本次申请就会失败.  

```C++
源文件:  source/mm/mmap.c 以RHEL内核2.6.32-642为例
 
0120 /*
0121  * Check that a process has enough memory to allocate a new virtual
0122  * mapping. 0 means there is enough memory for the allocation to
0123  * succeed and -ENOMEM implies there is not.
0124  *
0125  * We currently support three overcommit policies, which are set via the
0126  * vm.overcommit_memory sysctl.  See Documentation/vm/overcommit-accounting
0127  *
0128  * Strict overcommit modes added 2002 Feb 26 by Alan Cox.
0129  * Additional code 2002 Jul 20 by Robert Love.
0130  *
0131  * cap_sys_admin is 1 if the process has admin privileges, 0 otherwise.
0132  *
0133  * Note this is a helper function intended to be used by LSMs which
0134  * wish to use this logic.
0135  */
0136 int __vm_enough_memory(struct mm_struct *mm, long pages, int cap_sys_admin)
0137 {
0138         unsigned long free, allowed;
0139 
0140         vm_acct_memory(pages);
0141 
0142         /*
0143          * Sometimes we want to use more memory than we have
0144          */
0145         if (sysctl_overcommit_memory == OVERCOMMIT_ALWAYS)
0146                 return 0;
0147 
0148         if (sysctl_overcommit_memory == OVERCOMMIT_GUESS) { //Heuristic overcommit算法开始
0149                 unsigned long n;
0150 
0151                 free = global_page_state(NR_FILE_PAGES); //pagecache汇总的页面数量
0152                 free += get_nr_swap_pages(); //free swap的页面数
0153 
0154                 /*
0155                  * Any slabs which are created with the
0156                  * SLAB_RECLAIM_ACCOUNT flag claim to have contents
0157                  * which are reclaimable, under pressure.  The dentry
0158                  * cache and most inode caches should fall into this
0159                  */
0160                 free += global_page_state(NR_SLAB_RECLAIMABLE); //SLAB可回收的页面数
0161 
0162                 /*
0163                  * Reserve some for root
0164                  */
0165                 if (!cap_sys_admin)
0166                         free -= sysctl_admin_reserve_kbytes >> (PAGE_SHIFT - 10); //给root用户保留的页面数
0167 
0168                 if (free > pages)
0169                         return 0;
0170 
0171                 /*
0172                  * nr_free_pages() is very expensive on large systems,
0173                  * only call if we're about to fail.
0174                  */
0175                 n = nr_free_pages(); //当前free memory页面数
0176 
0177                 /*
0178                  * Leave reserved pages. The pages are not for anonymous pages.
0179                  */
0180                 if (n <= totalreserve_pages)
0181                         goto error;
0182                 else
0183                         n -= totalreserve_pages;
0184 
0185                 /*
0186                  * Leave the last 3% for root
0187                  */
0188                 if (!cap_sys_admin)
0189                         n -= n / 32;
0190                 free += n;
0191 
0192                 if (free > pages)
0193                         return 0;
0194 
0195                 goto error;
0196         }
0197 
0198         allowed = vm_commit_limit();
0199         /*
0200          * Reserve some for root
0201          */
0202         if (!cap_sys_admin)
0203                 allowed -= sysctl_admin_reserve_kbytes >> (PAGE_SHIFT - 10);
0204 
0205         /* Don't let a single process grow too big:
0206            leave 3% of the size of this process for other processes */
0207         if (mm)
0208                 allowed -= mm->total_vm / 32;
0209 
0210         if (percpu_counter_read_positive(&vm_committed_as) < allowed)
0211                 return 0;
0212 error:
0213         vm_unacct_memory(pages);
0214 
0215         return -ENOMEM;
0216 }
```



## 关于mmap只读共享的测试    
测试代码在github.com/zsummer/zbase/tests/mapping_test 中  

* 文件系统的内存映射分page cache 和buffer cache;    
* 只读共享就是单纯的page cache;    
* page cache 也会用到内存产生实际的内存使用(本来就是这样).   
* 文件系统的page cache带来的实际内存使用也会计算进该进程的'commit'中 如果有多个进程  每个进程都会计算到commit中.   用于oom打分    
    * 操作系统中的commit则只有一个  


从OOM角度来讲不区分共享内存 只考虑RSS(一直有有小的迭代 比如加入swap量, root进程判定等);     
page cache的回收由kswapd周期检查 通过内存水位判定, 基础参数是min_free_kbytes   
当前水线位置和详细信息在cat /proc/zoneinfo , 内存不够用时也会直接触发 .   
因此 mmap文件的virt 地址空间和OOM没关系,   mmap带来的rss会在被OOM killer之前回收掉不会被kill.    
