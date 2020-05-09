---
title: 内存分配器
date: 2020-05-09
categories: develop 
author: yawei.zhang 
---

### ..1. 目录  

### 核心思想和算法   

#### Sequential Fit  (连续链表)
 是基于一个单向或双向链表管理各个blocks的基础算法，因为和blocks的个数有关，性能比较差。这一类算法包括Fast-Fit, First-Fit, Next-Fit, and Worst-Fit。  

* Buddy System (Sequential Fit变种)  
  * 内部碎片化问题比较严重   
  * Binary Buddies  
  * Fibonacci Buddies  
  * Weighted Buddies   

#### Segregated Free List (离散式空闲列表) 
 将所有的空闲块，放入到一组链表中，每一个链表中只包含某一个大小范围的空闲块  

#### Indexed  Fit  
 通过一些高阶的数据结构来索引（Index）空闲的内存块。例如基于平衡树的“Best Fit”算法。
* 使用Balanced Tree的Best Fit allocator
* 使用Cartesian tree 的Stephenson Fast-Fit allocator
* Bitmap Fit (Indexed Fit 变种)
  Indexed Fit算法的变种，通过一小段内存的位图来标记对应的内存是空闲的还是使用中。  
  
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
* TLSF  

#### 援引
1. jemalloc关于使用red-block tree的反思 [链接]
  文章发布于2008年，作者在2009年将其应用于FaceBook时，则是进行了算法上优化。
2. 2011年jemalloc作者在FaceBook应用jemalloc后撰文介绍了jemalloc的核心算法及在Facebook上应用效果。[链接] [早期的论文，有更多的细节]
3. Android碎片化的度量 通过改造ROM做的实验。
4. Hoard Offical [链接]
5. Mac OS上malloc是怎么工作的[链接]
6. 关于WebKit应用tcmalloc的对比[链接]
7. How tcmalloc works[链接] [中文翻译]
8. TCMalloc源代码分析,很不错资料。作者的网站还有其它干货值得一读。[链接]
9. dlmalloc早期的技术文档，讲述了其核心算法。[链接]
10. ptmalloc源码分析,讲的很系统，非常值得一读。[CSDN下载链接]
11. 介绍jemalloc的资料《更好的内存管理-jemalloc》[链接]
12. 替换系统malloc的四种方法 [链接]
13. 介绍针对实时系统进行优化的内存分配算法TLSF，其中对动态分配算法(DSA)做了总结。[链接]
14. 维基百科上关于Thread Local Storage的说明, 也许你能感受到技术的相通性。[链接]
15. 针对实时系统进行各种分配算法的对比,可以结合13一起看。[链接]
16. ptmalloc,tcmalloc和jemalloc内存分配策略研究。[链接]
17. Firefox3使用jemalloc后的总结，可以看到Firefox优化的思路。[链接] [Firefox使用的源代码]
18. Chromimum Project: Out of memory handling, 里面有不错的观点。 [链接]
————————————————
版权声明：本文为CSDN博主「Horky」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
原文链接：https://blog.csdn.net/HorkyChen/java/article/details/35735103