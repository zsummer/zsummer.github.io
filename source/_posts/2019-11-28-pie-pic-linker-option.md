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


* -rdynamic  
  * 该选项指示链接器添加所有的符号到动态符号表, 不仅仅是用到的部分  
  * 在INTEL X64 linux gcc-6 未测试出该选项有否的异同 (也可认为是默认存在)   
    * 无论是否用过都会添加  

* -fpic    (position-independent code)  编译选项和链接选项  
  * 用于生成PIC 位置无关代码 的共享库, 在链接到EXE时如果GOT表超过某些特定机器指定的最大值时会返回错误, 这时需要使用-fPIC进行重新编译和链接   
* -fPIC 编译选项和链接选项  
  * 和-fpic一样, 但是回避掉了GOT大小的限制问题  
  * 在编译和链接时都需要指定    


* -fPIE  编译选项 
  * 编译位置无关代码, 和PIC相同, 但是PIE假定了编译出的目标文件用于链接成可执行文件  
  * 主要是访问外部符号时是否使用PLT/GOT  
  * 实际可用-fPIC代替(不假定目标文件的最终链接目的)   
  * -fpie 和-fpic一样  

* -pie  链接器选项
  * 用于生成 位置无关可执行文件 的可执行文件  
  * 生成的可执行文件的ELF类型不是EXEC而是和共享库一样DYN
  * 需要-fPIE配合使用 否则会出现访问外部符号时候无法正确找到的错误  
    * 这个问题等同用PIC链接非PIC编译的库

* 其他备注  

  * -no-pie  新版本g++比如6版本 默认启用pie 如不需要则要显式去除  
    * 部分编译器支持  

  * -fno-plt  
    * 部分编译器支持  

  * -fno-jump-tables
    * 部分编译器支持  
  
  * 动态库查找路径
    * 链接时如果要使用-l 则需要先-L指定目录  
    * 运行时如果不在系统指定目录的库需要设置LD_LIBRARY_PATH或者配置文件
      * 例如 简单设置export LD_LIBRARY_PATH="./" 路径    
  
  * --static 组织在链接时使用动态库

  * --shared 生成动态库

  * --static-libgcc 链接静态libgcc库

  * --shared-libgcc 链接动态libgcc库

  * -static和-shared可以同时存在 这样会创建共享库 但该共享库引用的其他库会静态地链接到该共享库中  
    * -Wl,--whole-archive 告诉链接器对其后面出现的静态库包含的函数和变量打包到动态库  
    * -Wl,--no-whole-archive 关掉特性  
      * 举例  -Wl,--whole-archive -la -lb -lc -Wl,--no-whole-archive

  * dlopen动态load共享库
