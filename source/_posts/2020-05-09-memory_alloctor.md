---
title: 内存分配器
date: 2020-05-09
categories: develop 
author: yawei.zhang 
---

## 内存分配器核心思想和算法

### 内存管理策略   

#### Sequential Fit  (连续适配)
 是基于一个单向或双向链表管理各个blocks的基础算法，因为和blocks的个数有关，性能比较差。这一类算法包括Fast-Fit, First-Fit, Next-Fit, and Worst-Fit。  



#### Segregated List (分离列表) 
 将所有的空闲块，放入到一组链表中，每一个链表中只包含某一个大小范围的空闲块  

* Buddy System (Sequential Fit变种)  
  * 内部碎片化问题比较严重   
  * Binary Buddies  
  * Fibonacci Buddies  
  * Weighted Buddies   
  
#### Indexed  Fit  
 通过一些高阶的数据结构来索引（Index）空闲的内存块。例如基于平衡树的“Best Fit”算法。
* 使用Balanced Tree的Best Fit allocator
* 使用Cartesian tree 的Stephenson Fast-Fit allocator
* Bitmap Fit (Indexed Fit 变种)
  Indexed Fit算法的变种，通过一小段内存的位图来标记对应的内存是空闲的还是使用中。  
  
### 路径匹配策略  
对于操作系统而言, 除了管理进程之外, 还需要有效的管理计算机的主内存, 管理主内存的共享使用和最小化内存访问时间是内存管理器的基本目标. 虽然使用了各种不同的策略来为争夺内存的进程分配空间，但最流行的三种策略是最佳匹配、最不适合匹配和首次匹配.    

* Best fit:   
  The allocator places a process in the smallest block of unallocated memory in which it will fit. For example, suppose a process requests 12KB of memory and the memory manager currently has a list of unallocated blocks of 6KB, 14KB, 19KB, 11KB, and 13KB blocks. The best-fit strategy will allocate 12KB of the 13KB block to the process.   
  最佳匹配:  
  这种匹配策略中, 分配器会从满足匹配要求的未分配内存中选择最小的块.  
  例如程序请求一个12kb的内存, 而当前的内存管理器有一个未分配的内存块列表, 分别为14k, 19k, 11k, 13k, 那么best-fit讲从13k的内存块中分配内存给程序.  


* Worst fit:  
  The memory manager places a process in the largest block of unallocated memory available. The idea is that this placement will create the largest hold after the allocations, thus increasing the possibility that, compared to best fit, another process can use the remaining space. Using the same example as above, worst fit will allocate 12KB of the 19KB block to the process, leaving a 7KB block for future use.  
  最不适合匹配  
  内存管理器总是选择获得的最大的那个未分配内存块. 
  这种策略在每次分配后总是持有最大的内存块, 从而增加匹配的可能性. 与最佳匹配相比, 其他的请求可以使用剩余的空间.(最佳匹配的剩余内存往往无法利用)  
  同上例, 最坏匹配会从19k的那个内存块中分配, 并留下7k的内存留给将来使用.  

* First fit:  
  There may be many holes in the memory, so the operating system, to reduce the amount of time it spends analyzing the available spaces, begins at the start of primary memory and allocates memory from the first hole it encounters large enough to satisfy the request. Using the same example as above, first fit will allocate 12KB of the 14KB block to the process.  
  通常内存中会存在很多空洞, 所以操作系统为了减少分析可用空间的性能(时间)消耗, 会从主要内存或者 第一个足够大并且满足求要的可分配内存的起始位置相应请求.   
  同上例中, 首先匹配会从14k的block中分配12k的请求.   
  First Fit的一个改良版本叫做Next Fit, 即在下次请求时会从上次中断的地方的开始搜索, 从而避免总是从起始的空闲内存开始查找. (Designated victim), First Fit的策略会倾向于总是把大块切的更零碎也因此带来更多的外部碎片问题, 也因为总是从空闲内存的头部开始切造成更多的内部碎片,  而Next Fit的做法会避免(改良)这些问题, 并且速度比Firt 以及 Best更快.  



#### TLSF: a New Dynamic Memory Allocator for Real-Time Systems   
通过一组链表来管理不同大小内存块的内存分配算法。
适用环境和要求:
内存分配/释放的执行时间可预期，可接受的。由于RTOS对指令的执行时间有严格要求，所以常常采用静态内存分配的方法，以获得一个可以预期的执行时间。
内存分配算法的碎片化程度要低，这是由于RTOS往往长时间执行，碎片化程度高会导致内存分配失败。
实时系统动态内存算法
可信的执行环境，Trusted Environment，应用不会故意破坏数据或者窃取数据。
有限的物理内存。
没有物理MMU来支持虚拟内存。

核心概念: Two Level
基本的Segregated Fit算法是使用一组链表，每个链表只包含特定长度范围来的空闲块的方式来管理空闲块的，这样链表数组的长度可能会很大。如下图，TLSF为了简化查找定位过程，使用了两层链表。第一层，将空闲内存块的大小根据2的幂进行分类，如（16、32、64...）。第二层链表在第一层的基础上，按照一定的间隔，线性分段。比如2的6次方这一段，分为4个小区间【64,80），【80,96），【96,112），【112，128）.每一级的链表都有一个bitmap用于标记对应的链表中是否有内存块。比如第一级别bitmap的后4bit位0100，即2的6次方这个区间有空闲块。对应的第二级链表的bitmap位0010及【80,96）这个区间有空闲块，即下面的89 Byte。



策略: 
Immediate coalescing，立即合并，当内存块被释放后，立即与相邻的空闲内存块合并，以获得一个更大的空闲块，插入到链表的相应位置。这样可以减少碎片化。
Splitting threshold，分割阈值，最小可分配的内存块大小为16字节，应用一般不会分配一些基本的数据结构，如int、char等。限定最小可分配大小为16字节，这样可以在空闲的内存块中存储一些管理信息。
Good-fit strategy，TLSF会尽可能的返回一个最小的、能够满足需求的内存块。
Same strategy for all block sizes，对于不同大小的内存请求，TLSF只有一个分配策略，实现相对简单，执行时间可以预期。相应的dlmalloc根据所请求的内存大小不同，有多达4种内存分配策略。
Memory is not cleaned-up，分配个应用的内存没有被请0.

特点:
可以预期的分配执行时间，无论对于多达的内存分配请求，TLSF可以在限定的时间内完成分配。
碎片化程度低。


#### mimalloc:


#### 多线程

* 局部化, 本地缓存/链表  
* 注意false shared  
* 跨线程队列 最大本地缓存 

#### 内存安全   
管理数据和被管理内存分离
buddy system
pages 管理  

可信的执行环境Trusted Environment，应用不会故意破坏数据或者窃取数据  
有限的物理内存  
有限的物理地址  
没有物理MMU来支持虚拟内存

#### 开源内存分配器  
* dlmalloc 
* tcmalloc  
* jemalloc  
* Hoard
* minimalloc
* TLSF: https://github.com/OlegHahm/tlsf    

#### 援引
[jemalloc深入分析 PDF](https://github.com/everschen/tools/blob/master/DOC/Jemalloc.pdf)  
[jemalloc 2015演讲视频 tick tock, malloc needs a clock 背景和初始设计思想介绍](http://applicative.acm.org/2015/applicative.acm.org/speaker-JasonEvans.html)   
[jemalloc facebook工程贴](https://www.facebook.com/notes/facebook-engineering/scalable-memory-allocation-using-jemalloc/480222803919)   
[BSDcan paper 2006](http://people.freebsd.org/~jasone/jemalloc/bsdcan2006/jemalloc.pdf)   
[On the Impact of Memory Allocationon High-Performance Query Processing](https://dl.acm.org/doi/abs/10.1145/3329785.3329918)   
[How tcmalloc Works](https://www.jamesgolick.com/2013/5/19/how-tcmalloc-works.html)   
[Chromimum Project: Out of memory handling](https://www.chromium.org/chromium-os/chromiumos-design-docs/out-of-memory-handling)  
[Scalable Memory Allocation TBB](https://rd.springer.com/content/pdf/10.1007%2F978-1-4842-4398-5_7.pdf)  
[ptmalloc,tcmalloc和jemalloc内存分配策略研究](https://cloud.tencent.com/developer/article/1173720)   

