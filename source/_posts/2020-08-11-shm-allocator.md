---
title: 一种适合共享内存RESUME方案的通用内存分配器设计方案和实现 
date: 2020-08-11
categories: develop 
author: yawei.zhang 
mathjax: true
---

<!-- TOC -->

- [前言](#%E5%89%8D%E8%A8%80)
- [基本原理](#%E5%9F%BA%E6%9C%AC%E5%8E%9F%E7%90%86)
- [内存分配器的基本概念](#%E5%86%85%E5%AD%98%E5%88%86%E9%85%8D%E5%99%A8%E7%9A%84%E5%9F%BA%E6%9C%AC%E6%A6%82%E5%BF%B5)
    - [显示和隐式分配器](#%E6%98%BE%E7%A4%BA%E5%92%8C%E9%9A%90%E5%BC%8F%E5%88%86%E9%85%8D%E5%99%A8)
    - [设计要求和目标](#%E8%AE%BE%E8%AE%A1%E8%A6%81%E6%B1%82%E5%92%8C%E7%9B%AE%E6%A0%87)
        - [内部碎片和外部碎片问题](#%E5%86%85%E9%83%A8%E7%A2%8E%E7%89%87%E5%92%8C%E5%A4%96%E9%83%A8%E7%A2%8E%E7%89%87%E9%97%AE%E9%A2%98)
- [基础分配策略](#%E5%9F%BA%E7%A1%80%E5%88%86%E9%85%8D%E7%AD%96%E7%95%A5)
    - [基础存储方式](#%E5%9F%BA%E7%A1%80%E5%AD%98%E5%82%A8%E6%96%B9%E5%BC%8F)
        - [Sequential Fit  连续适配](#sequential-fit--%E8%BF%9E%E7%BB%AD%E9%80%82%E9%85%8D)
        - [Segregated List 分离列表](#segregated-list-%E5%88%86%E7%A6%BB%E5%88%97%E8%A1%A8)
        - [Indexed  Fit](#indexed--fit)
    - [路径匹配策略](#%E8%B7%AF%E5%BE%84%E5%8C%B9%E9%85%8D%E7%AD%96%E7%95%A5)
        - [Best fit](#best-fit)
        - [Worst fit](#worst-fit)
        - [First fit](#first-fit)
- [设计方案](#%E8%AE%BE%E8%AE%A1%E6%96%B9%E6%A1%88)
    - [设计需求:](#%E8%AE%BE%E8%AE%A1%E9%9C%80%E6%B1%82)
    - [设计方式:](#%E8%AE%BE%E8%AE%A1%E6%96%B9%E5%BC%8F)
    - [代码规模和最终性能](#%E4%BB%A3%E7%A0%81%E8%A7%84%E6%A8%A1%E5%92%8C%E6%9C%80%E7%BB%88%E6%80%A7%E8%83%BD)

<!-- /TOC -->


## 前言    
在之前的文章我比较全面的介绍了一个完整的resume机制的阐述, 也提到了一些开发成本和三方库移植的问题, 这篇文章主要介绍如何在共享内存上实现一套可动态扩容的通用内存分配器, 以及如何利用通用内存分配器进行三方库包括stl中容器类的快速resumable化.       

通用动态内存分配器的实现可以很好的对共享内存RESUME机制进行一个补充,  例如可以简单的基于分配器实现stl的allocator, 从而直接得到resumable的vector, list, queue, map, multi_map, unorder_map等;   也可以简单的将一些本身就比较容易resumable化的三方库和算法替换其allocator来简单快速的完成移植工作而非重写他们.   例如常见的资源解析rapidxml   移动避免算法库rvo等  .  

当然, 处理易用性和快速移植三方库这些优点外, 从项目角度考虑也有一些缺点需要关注并进行合理范围的使用.   

相比静态内存机制下的resumable方案 
* 较难估算内存峰值用量  
  * 有些场合下该难点是业务需求带来的, 比如说我们普通玩家可以设置可绑定的上限buff100个就够用, 但是对于一些GVE的大型BOSS团本来说, 100个就容易超限,  在扁平化的设计中, 如果我们用静态内存方案那么所有单位的内存使用量都是'上限', 但是改成动态方案 则是根据真实情况动态波动的.  我们可以根据策划配置通过软上限来进行计算, 但是业务功能量级铺设上来后 则很难全面的评估这些地方对内存使用的真实情况.     
  * 静态内存中在启服时可以一次性的计算好所有内存大小, 整个游戏无论负载情况其内存占用是始终稳定且直观的 .   

* 内存安全性不如静态内存   
  * 静态内存基本上不存在野指针 越界等问题  也不存在内存不够用的情况   
  * 例如说我实现了```static_list```; 
    * 定义声明了OBJ和总大小 ```static_list<Buff, MAX_BUFF_SIZE> buffs;```  
    * 然后我引用了一个指针指向其中一个已有的元素进行当前被动动作标记, 在受击出现的时候```Buff* act = &受击BUFF;```  在受击结束时候在移除act;  这里虽然用到了指针 但是在使用的时候, static_list中所有的元素都在一个连续的静态内存区域内, 并且该指针可以通过偏移检测和bitmap计算是否是有效的obj指针, obj是不是有效的buff等, 并不会因为是指针出现越界访问问题.  

* 定位一些内存访问相关的问题可能会更麻烦一些   
  * 例如:  所有战斗单位位于共享内存xxx--yyy地址内以大小X对齐, 每个单位内聚合有技能模块移动模块属性模块.  假如现在出现了一个读取属性错误的问题, 我们很容易根据有限的地址信息去推测出出问题的范围, 并且方便进行基于内存地址的修改情况进行监听断点等  

* 性能相比静态方案一般会有性能上的损失,  动态内存的分配和回收有一个适配的成本开销.   

* 长期运行可能有内存碎片问题
  * 这个问题反而比较乐观, 因为在静态内存池方案上 内存利用率往往是非常低的, 而动态内存分配器的碎片率一般根据情况大约都控制在25%以下, 像dlmalloc则在实践中能控制在95%左右.  
  * 静态内存一般来说, 对象池与对象池之间是内存隔离的, 即相互之间的空闲内存不能共用    
  * 无论是对象池还是容器, 其规模都是直接以'上限'在定义阶段确定的, 一般情景下都会有大量的富余容量浪费  

<!--more -->
## 基本原理      

在共享内存紧邻静态内存区域, 划分出动态管理区域并支持动态增长扩容的区域     
```
|global state|  obj pools  |  dyn mgr |                     |  dyn segment 1 | dyn segment N ...   
| <-- 启服时候根据配置直接计算出大小 --> |  <-- alian size --> | <---   动态分段扩容  ----->  ...
```

## 内存分配器的基本概念

### 显示和隐式分配器   
这是一个基础的分类,  无论显式分配器还是隐式分配器都需要显式指定分配,  但是显式分配器还需要显式指定回收.   

一般我们经常接触到的malloc/free (ptmalloc分配器),  tcmalloc  jemalloc等都是显示分配器  

而不需要显式指定回收的内存分配器, 通常我们称之为垃圾收集器, 隐式分配器会自动回收不再被使用内存,  也因此通常其实现需要语言级别的支持和配合. 

### 设计要求和目标   
要求:  
* 处理任意请求序列   
  * 对于任意的请求和回收序列都能正确执行   
* 立即响应请求
  * 对于内存分配请求需要立刻响应 不能缓存
* 只使用堆   
  * 对于给系统用的内存分配器 只使用堆可以有更好的移植性   
  * 对于共享内存RESUME而言, 对应的是 我们只能使用共享内存  
* 对齐块   
  * 一般来说通用内存分配器会提供两倍CPU位宽的对齐以保证对任意类型数据访问的支持, 一个错误的实现假设例如 在64位下只提供32位的对齐  那么去读取一个void*指针  则特定情况可能会导致CPU两次读取带来额外的性能开销甚至可能产生硬件异常.    
* 不修改/移动已分配块
  * 没有缺页中断这类机制支持 修改或者移动已分配块会直接导致上层功能异常 
  
目标:  
* 最大化吞吐率
* 最大化内存利用率, 减少管理内存大小, 减少内部碎片, 减少外部碎片

#### 内部碎片和外部碎片问题  
内部碎片:简单描述就是已分配块中的无效负荷部分   
  * 例如因为对齐要求, 当用户分配9字节数据时候, 给出的已分配块为16,  那么就产生了7字节的内部碎片   
  * 通常内部碎片的问题简单明了容易量化, 只要在可接受范围都可以.    
外部碎片: 空闲内存合计能满足请求, 但是因为非连续, 导致没有任何一块单独的空闲内存能满足需求.   
  * 例如在1M的空闲内存以512k大小分散在两个地方,  这个时候任何大于512k的请求都无法成功分配   
  * 在通用的内存分配器中要求中, 外部碎片无法避免并且难以量化, 更准确的描述是, 外部碎片的产生不仅取决于之前请求的模式和分配器实现方式, 还取决于未来即将发生的请求的模式.    
    * 举例来说 我们从1M内存中开采512k后再开采1K, 那么如果后续的请求中释放了512k的这个分配块 就出现了外部碎片问题.   
  * 通常 如果我们对请求加以限制, 例如规定开采粒度都是512k  那么就可以通过内部碎片来优化一部分外部碎片问题.   
  * 对于一个长期运行的系统来讲, 外部碎片是一个非常值得留意的问题.    

## 基础分配策略  

### 基础存储方式   

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

#### Best fit   
  The allocator places a process in the smallest block of unallocated memory in which it will fit. For example, suppose a process requests 12KB of memory and the memory manager currently has a list of unallocated blocks of 6KB, 14KB, 19KB, 11KB, and 13KB blocks. The best-fit strategy will allocate 12KB of the 13KB block to the process.   
  最佳匹配:  
  这种匹配策略中, 分配器会从满足匹配要求的未分配内存中选择最小的块.  
  例如程序请求一个12kb的内存, 而当前的内存管理器有一个未分配的内存块列表, 分别为14k, 19k, 11k, 13k, 那么best-fit讲从13k的内存块中分配内存给程序.  


#### Worst fit  
  The memory manager places a process in the largest block of unallocated memory available. The idea is that this placement will create the largest hold after the allocations, thus increasing the possibility that, compared to best fit, another process can use the remaining space. Using the same example as above, worst fit will allocate 12KB of the 19KB block to the process, leaving a 7KB block for future use.  
  最不适合匹配  
  内存管理器总是选择获得的最大的那个未分配内存块. 
  这种策略在每次分配后总是持有最大的内存块, 从而增加匹配的可能性. 与最佳匹配相比, 其他的请求可以使用剩余的空间.(最佳匹配的剩余内存往往无法利用)  
  同上例, 最坏匹配会从19k的那个内存块中分配, 并留下7k的内存留给将来使用.  

#### First fit  
  There may be many holes in the memory, so the operating system, to reduce the amount of time it spends analyzing the available spaces, begins at the start of primary memory and allocates memory from the first hole it encounters large enough to satisfy the request. Using the same example as above, first fit will allocate 12KB of the 14KB block to the process.  
  通常内存中会存在很多空洞, 所以操作系统为了减少分析可用空间的性能(时间)消耗, 会从主要内存或者 第一个足够大并且满足求要的可分配内存的起始位置相应请求.   
  同上例中, 首先匹配会从14k的block中分配12k的请求.   
  First Fit的一个改良版本叫做Next Fit, 即在下次请求时会从上次中断的地方的开始搜索, 从而避免总是从起始的空闲内存开始查找. (Designated victim), First Fit的策略会倾向于总是把大块切的更零碎也因此带来更多的外部碎片问题, 也因为总是从空闲内存的头部开始切造成更多的内部碎片,  而Next Fit的做法会避免(改良)这些问题, 并且速度比Firt 以及 Best更快.  


## 设计方案       

如何设计一个适用于共享内存上支持resumable的通用动态内存管理系统?  这里借鉴了linux下的设计布局.  
参考我之前写的两篇文章:  
[基于共享内存的通用内存分配器](https://zsummer.github.io/2020/02/07/2020-02-07-shared-memory-buddy_system/)
[基于共享内存的对象池管理方案](https://zsummer.github.io/2020/02/07/2020-02-03-shared-memory-resume-overview/)

### 设计需求:   

* 不考虑多线程  
* RESUMABLE支持  
* 通用内存分配器的必要条件必须全部满足   
  * 任意大小任意序列的请求支持  
  * 立即响应请求   
  * 保证内存的对齐要求 
  * 不移动压缩已分配块    

### 设计方式:  
* 大块共享内存的连续地址空间下的动态扩容
* buddy system算法来作为底层实现  
  * 满足任意大小的请求序列
  * 通过约束上层小内存分配器的批发粒度来降低外部碎片的发生   
  * 满足大内存对齐而不产生内部碎片 (对于现代tcmalloc mimalloc等meta方案进行支持)    
* zmalloc小内存分配方案  
  * 1k以下的内存使用朴素的分箱方案(Segregated List)   
    * best fit 方案 
  * 1k以上的内存请求使用$2^{n-3}$进行对齐, 即最大浪费约12.5%的内存进行分箱   
    * best fit 方案  
    * dlmalloc使用$2^{n-2}$进行分箱, 箱内使用一个刚刚好够用的bit前缀树进行空间内不同大小的已分配块管理, 可以达到接近100%的利用率 而对齐只要一行代码即可完成.   性能上理论上比对齐方式略差  实测基本上没有什么差距.  
    * tcmalloc mimalloc均采用对齐这种方案
  * 超过大小内存请求上限大小的内存, 则'直接'交给底层的buddy system完成, zmalloc只提供统一接口.   
  * 牺牲块开采    
    * 这是进行了first fit优化的一个关键点 也是性能的关键    
    * 在best fit的快速bitmap判定失败后会从牺牲块进行开采, 如果没有牺牲块则批发一个大块作为牺牲块进行开采.   
    * 这里采用牺牲块有更良好的通用性性能,  指令路径短, cpu cache友好   
    * 这里没采用tcmalloc/mimalloc的page设计, 在相同大小的连续请求中会比这种方案要好, 但是牺牲块的设计则通用性上更好, 性能差距即使针对性的情景下也很难超过5%  
  
### 代码规模和最终性能  
这两种方案核心代码都是几百行级别, 但是考虑到coverage测试代码, 必要的辅助流程代码和assert调测(单元代码不在实现文件中), buddy system和zmalloc的实现部分代码均在1000行出头即可完成.   
性能测试中, 同dlmalloc mimalloc tcmalloc的生产环境中性能差距均小于5%,  在项目整体的压测中无可观测的性能波动.   

(tcmalloc相比ptmalloc的提升明显的部分在多线程部分的设计, 现代分配器tcmalloc/jemalloc/mimalloc等均做了局部化处理, 老的ptmalloc则只是在dlmalloc上做了多线程支持和细节优化 所以差距会比较明显)





