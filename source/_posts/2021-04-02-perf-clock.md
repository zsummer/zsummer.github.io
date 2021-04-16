
---
title: 常用计时工具性能对比  
date: 2021-02-19
categories: develop 
author: yawei.zhang 
mathjax: false
---


* C库函数 time(NULL)
  * WIN32 计数精度为1s  获取消耗32ns  
  * linux 计数精度为1s  获取消耗2ns  
  * MAC   计数精度为1s  获取消耗155ns  

* C库函数 clock  
  * WIN32 计数精度为1ms  获取消耗38ns  
  * linux 下计数精度为1us 获取消耗122ns(Intel X5650 下766ns, mac:476)  实际测试精度准确度在100ms级别(误差有几十ms 唯一一个有误差)    

* C++ chrono : high_resolution_clock是通常为steady clock(实现定义 最好指定为steady)  
  * WIN32 system_clock 计数精度为100ns    获取消耗25ns DEBUG 39ns
  * WIN32 steady_clock 计数精度为100ns    获取消耗18ns DEBUG 65ns
  * linux system_clock 计数精度为1ns      获取消耗20ns DEBUG 25ns  
  * linux steady_clock 计数精度为1ns      获取消耗19ns DEBUG 26ns
  * linux system_clock 计数精度为1ns      获取消耗33ns DEBUG  
  * linux steady_clock 计数精度为1ns      获取消耗45ns DEBUG  
* QueryPerformanceCounter   
  * 计数精度为1ns    获取消耗28ns 
* GetSystemTimeAsFileTime  
  * 计数精度为1us    获取消耗4ns/23ns 
* clock_gettime
  * 相同CPU不同选项下甚至DEBUG/RELEASE下的区别差异都较大  多台不同硬件和linux发行版下相对稳定可用的为CLOCK_REALTIME  
  * 计数精度为1ns    获取消耗18ns  
  * 如果需要使用需要先本地测试, 性能消耗可能不符合预期(参考rdtscp数据)  
* rdtsc  
    * 计数精度为0.4ns左右 取决于主频   获取消耗7ns （18 circle） 
* rdtscp  
    * 计数精度为0.4ns左右 取决于主频   获取消耗2.58us (X5650双路CPU下600us/2.28s)  
* load fence rdtsc   
  * 计数精度为0.4ns左右 取决于主频   获取消耗9ns  (24 CPU CIRCLE)  (MAC 13ns)
* load&store fence rdtsc   
  * 计数精度为0.4ns左右 取决于主频   获取消耗15ns 
  * 
* __rdtsc (WIN32)  
  * 计数精度为0.4ns左右 取决于主频   获取消耗9ns (24 CPU CIRCLE) 

* 对比测试  
  * 寄存器操作 1个circle   
  * L1 cache hit  3个circle  (不考虑在流水线中等情况)  
  * L2 cache hit  12个circle    
  * L3 cache hit  38个circle  
  * 主内存 65ns   
  * NUMA内存 相比主内存增加总线访问延迟 约40ns   

  * 三元赋值一般约8个circle (存在指令并行,预读等和其他周围代码一起统计会有推算上的偏差)
  * s64类型两次乘法一次除法计算一次三元赋值和若干普通赋值的cpu统计代码消耗约为3.71ns  (大样本均摊) 
  * s64类型两次乘法           一次三元赋值和若干普通赋值的cpu统计代码消耗约为2.93ns  (大样本均摊) 
  * 4次加法赋值 1.59ns  (大样本均摊)   

* 小结   
  *  一般CPU主频是2.5\~4Ghz之间(对本文来说为标频, 睿频无意义),  标频通常代表着高精度计数的极限(INTEL平台下和同时和ART硬件有关)
     *  计数极限为标频倒数 按照主流CPU的标频而言  通常最高精度在0.4\~0.2ns左右;  
     *  读取和使用计数也需要执行指令 执行指令需要CPU计算    
     *  读取和使用计数可能涉及到指令以及计数的缓存内存操作等     
     *  不加保护的rdtsc约7ns (本文I7 3.7g主频CPU)  
  
  * std::chrono的稳定性和精度均为良好 并且跨平台性最好(C++11标准)   
    * 通常在20\~65ns左右(大概测试了3台windows 5台linux 1台mac (均是INTEL CPU))  
    * 100ns以下的获取损耗 以及1ns精度   
  
  * rdtsc精度最高 速度最快 稳定性最好 但是需要确认CPU体系和版本保证可用(当前只针对INTEL/AMD上市年份在07/08年以后的新CPU)   
    * 通常稳定在10ns以下或者说在30个CPU周期之内, 几乎不受编译选项和平台影响, 并且不同CPU损耗接近;
    * 横向对比则相当于4次三元取值指令的性能开销   
    * 对于指令级粒度的性能测试,  以及进行高频函数的性能统计采样中,  更小的性能开销和更高的精度具有不可取代的作用和价值.     
      * 对于9ns的代码段进行独立性能测试 rdtsc测试为11~15ns, chrono测试为44~50ns  (对应每秒1亿次规模的代码段进行性能对比 rdtsc 44.4% chrono 422%  提高了10倍的精度 chrono统计的数据在该级别基本无意义) 
      * 对于80ns的代码段进行独立性能测试 rdtsc测试为82~85ns, chrono测试为100~122ns  (对应每秒1千万次规模的代码段进行性能对比 rdtsc 4.4%,  chrono 48.4% 提高了10倍的精度 rdtsc在该级别已经非常精准, chrono偏差较大) 
  
  
  * 该小结中未列举到的其他方案 存在以下问题不推荐使用 
    * 性能开销太大或者不稳定  
    * 精度不够或者不稳定  
    * 不同编译选项或者平台差异过大  
