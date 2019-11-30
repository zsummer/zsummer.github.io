---
title: 位置无关代码生成(重定位)选项和说明 GCC     
date: 2019-11-28
categories: develop 
author: yawei.zhang 
---

### 目录  
- [目录](#目录)
- [选项说明](#选项说明)


### 选项说明      

* -shared   
  * 编译一个共享库时候要始终指定 -fPIC -fpic或者编译器的其他变种选项     
  * -shared 和-static可以同时存在 因此可以编译出'纯静态的'的so


* -rdynamic  
  * 该选项指示链接器添加所有的符号到动态符号表, 不仅仅是用到的部分  
  * 在INTEL X64 linux gcc-6 未测试出该选项有否的异同 (也可认为是默认存在)   
    * 无论是否用过都会添加  

* -fpic    (position-independent code)
  * 用于生成PIC 位置无关代码 的共享库, 在链接到EXE时如果GOT表超过某些特定机器指定的最大值时会返回错误, 这时需要使用-fPIC进行重新编译和链接   
* -fPIC 
  * 和-fpic一样, 但是回避掉了GOT大小的限制问题  
  * 在编译和链接时都需要指定    

* -fpie
* -fPIE  编译选项  
  * 和-fpic类似,  这个选项是(只)用来生成链接到可执行文件 的 位置无关代码    
* -pie  链接器选项
  * 用于链接 位置无关可执行文件 的可执行文件  
* -fpie -fPIE -pie 同时使用可生效   
  * 最初的实现来自redhat -pie,  因此总是要配合-pie使用才会有效.    
  * 位置无关可执行文件的ELF类型为DYN 和共享库一样    
  * 未使用该选项生成的是EXEC类型


* -no-pie  新版本g++比如6版本 默认启用pie 如不需要则要显式去除  


