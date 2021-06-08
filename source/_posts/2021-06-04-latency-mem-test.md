
---
title: 高性能编程:内存访问性能分析和常见数据结构  
date: 2021-06-04
categories: develop 
author: yawei.zhang 
mathjax: false
---

## CPU CACHE   
在计算机系统中，CPU高速缓存（英语：CPU Cache，在本文中简称缓存）是用于减少处理器访问内存所需平均时间的部件。在金字塔式存储体系中它位于自顶向下的第二层，仅次于CPU寄存器。其容量远小于内存，但速度却可以接近处理器的频率。

当处理器发出内存访问请求时，会先查看缓存内是否有请求数据。如果存在（命中），则不经访问内存直接返回该数据；如果不存在（失效），则要先把内存中的相应数据载入缓存，再将其返回处理器。

缓存之所以有效，主要是因为程序运行时对内存的访问呈现局部性（Locality）特征。这种局部性既包括空间局部性（Spatial Locality），也包括时间局部性（Temporal Locality）。有效利用这种局部性，缓存可以达到极高的命中率。

在处理器看来，缓存是一个透明部件。因此，程序员通常无法直接干预对缓存的操作。但是，确实可以根据缓存的特点对程序代码实施特定优化，从而更好地利用缓存。

<!-- more -->

### 基础结构   
基础术语:

* cache set   
  * a "row" in the cache; 在层级关系中, cache分为多个条目, 每行条目称为set;    

* cache block/ cache line :
  * cache 存储的最小单元, 一般包含多个字节; 在讲cache实现的地方一般使用block; (2021)常见的X86-64服务器上多为64字节;   
  * 数据以cache block固定大小在内存和缓存之间传输

* cache tag 
  * 每块数据都对应一个tag用来作为数据的身份标识, 通常一个缓存位置可以映射不同的内存, 使用tag进行区分.    
* valid bit  
  * 对应block位置是否存在有效缓存  
* cache offset 
  * 对应block大小的偏移量  

基础访问流程:   
* 通过给定内存地址定位该内存所在的cache set    
* 检查该set下所有的cache block关联的cache tag, 如果发现匹配则存在block; (通常电路设计中是并行检查, 电路成本比较昂贵)    
* 如果找到匹配的block, 检查valid bit位, 为1则代表缓存有效     

基础的cache映射结构, 主流为组关联结构, 为方便描述, set数量定义为N, 每个set下的block数量定义为M:   
* 直接映射 Direct-mapped cache   
  * N*1 结构,  每个set只有一个block   
  * 优点: 实现结构简单 定位到set后直接检查唯一的一个block即可确认缓存是否命中.    
  * 缺点: 缓存利用率低, 并且存在更多的冲突      
* 全相连 Fully associative cache  
  * 1*M结构, 只有一个set, 所有block都在一个set下面    
  * 优点: 缓存利用率高, 冲突少, 并且有多种替换的算法可以使用      
  * 缺点: 硬件昂贵, 映射过程耗电且慢(需要执行完所有检查, 要么硬件昂贵 要么遍历访问带来更长的延迟)  
* N路组相连 Set-associative cache  
  * N*M结构, 直接映射和全相连都相当于组相连的特例情况, 是一个折中方案   
  * 优点和缺点, 相比直接映射和全相连, 比较经济, 大多数CPU都是N路组相连, core I7或者志强一般 L1,L2是4~8路组相连, L3是8~16路组相连   


## 内存读取的性能层级   
* L1 cache  
  * 一般访问消耗的指令周期约为3  
* L2 cache  
  * 一般访问消耗的指令周期约为9~11  
* L3 cache  
  * 一般访问消耗的指令周期约为40~60  
* 内存   
  * 一般访问消耗的指令周期约为265~290

测试方法:   
一般通过构建一个远大于L3 cache大小的内存块,  以大于cache line的stride长度进行步进回环访问,  则可以统计出来L1, L2, L3的实际缓存大小和访问延迟.  细节可参见zperf的cpu_cache_test   

内存的访问延迟一般是超过100ns, 在NUMA的多路CPU系统中, 访问远程内存会有更多的延迟(一般至少增加50% 一般为一倍).  

从寄存器到内存性能差异约在300~450倍,  从L1到内存性能差异在100~150倍左右,  很明显, 想要优化性能, 除了尽可能的利用好指令级并行计算, 所有涉及到存储访问的地方都需要尽可能的提高缓存友好型.    



## 优化案例   

见zperf的cpu_cache_matrix测试 可以有效提高二维或者三维空间的管理性能  



## reference
NUMA基础结构示意  
* NUMA   
  * NODE1 (对应一个socket 一个屋里CPU插槽)
    * Core (物理)核心1  
      * Threads 超线程核心(超标量CPU的同时多线程, 逻辑核)   
      * Threads  
      * ALU
      * FPU
      * L1 Cache
      * L2 Cache  
    * Core 核心2  
    * Core 核心...  
    * Uncore 
      * 内存控制器 MC (现在已经移入CPU 叫iMC)  通过iMC直接访问的内存叫本地内存  
      * PCIe Root Complex(现在也已经移入CPU )   
      * QPI switch 通过QPI链路再通过iMC访问的内存称为远程内存 intel ivy bridge下的NUMA平台延迟增加一倍   
      * L3缓存  
      * CBox  
      * 其他外设控制器   
  * NODE2
  * NODE...