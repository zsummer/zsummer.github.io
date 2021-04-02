---
title: GCC 内联汇编编写  
date: 2021-04-02
categories: develop 
author: yawei.zhang 
mathjax: false
---

本文阐述了GCC提供的内联汇编功能的使用和用法    
本文主要为了阐述zperf性能分析器的核心编写逻辑.  

<!-- toc -->  

## 概述   

在这篇文章中, 主要介绍的是(GCC)内联汇编函数的基本格式和用法, 这里先介绍两个基本概念.    

### 内联(inline):  
在C++中, inline关键字首先是**C++语言层面的修饰符**,  如同static/ const等.   
该关键字的作用是将函数声明为一个内联(inline)函数: inline关键字作为指示器传递给优化器"**优先采用函数的内联替换而非进行函数调用**".    
> 即内联函数原本的优化目的 不使用控制转移指令跳转到函数体, 而是直接拷贝函数体到发生调用的位置, 从而达到避免函数调用的开销以及传参和返回等开销.    

这里容易产生混淆的地方在于, 该修饰符对于上述优化的指示并非强制,  并且编译器拥有对任何未标注inline的函数的使用内联替换的自由(在编译的优化原则内);  
也因此在实际的实践中,  **inline关键字对于函数的含义也从'优先内联'实际变成了'容许多次定义'**,  并且该inline关键字在语义上的实际变化也**在C++17得到的标准化的定义和进一步的扩展**,  并进一步扫清了"header only"支持的剩余障碍.     


### 内联汇编  
内联汇编提供了在C/C++代码中直接嵌入汇编代码的能力, 其中, 'asm'关键字充当了汇编指令和'C/C++'代码之间的接口.   

<!-- more --> 

## GCC汇编基本语法  

GCC 使用AT&T/UNIX汇编语法, 这里主要给出和INTEL的基础差别, 更多详细内容查看对应的汇编手册, 或者[汇编语法和惯例](https://zsummer.github.io/2019/12/11/2019-12-11-asm-syntax/)   


* Source-Destination Ordering 操作数顺序  
    AT&T语法中操作数的方向与Intel汇编相反; 
    在Intel语法中, 第一个操作数是目标, 第二个操作数是源; 而在AT&T语法中是反过来的.  
    AT&T 语法: ```Op-code src dst```
    Intel语法: ```Op-code dst src```   
    

* 寄存器命名: 
  * 寄存器名称以%为前缀, Intel无前缀.  例如如果使用寄存器```eax```,  AT&T汇编需要写成```%eax```   

* 立即操作数  
  * AT&T立即数以$为前缀, Intel无前缀   例如 立即数1987 AT&T汇编要写成```$1987```  
  * 十六进制立即数 AT&T以0x为次前缀,  Intel以h为后缀进行修饰.  例如16进制 0x1987 
    * AT&T汇编: ```$0x1987```
    * Intel汇编: ```1987h```
  
* 操作数大小  
  * AT&T语法: 存储操作数的大小由操作码名称的最后一个字符确定, 'b', 'w', 'l' 对应字节码对应8位, 16位,32位.  
    * 例如: ```movl    %eax, %ebx  ```  
  * Intel语法: 添加前置修饰符 例如'byte ptr' 'word ptr' 'dword ptr'来实现   
    * 例如: ```mov         qword ptr [rax+8],0 ```  

* 内存操作数  
  * AT&T汇编中的语法```segment:displacement(base register, index register, scale factor)```
  * Intel等效语法  ```segment:[base register + displacement + index register * scale factor]```   

* 简单对比示例如下:  

|      AT&T Code                     |       Intel Code             |
|------------------------------------|------------------------------|
|  movl    $1,%eax                   | mov     eax,1                |   
|  movl    $0xff,%ebx                | mov     ebx,0ffh             |   
|  int     $0x80                     | int     80h                  |   
|  movl    %eax, %ebx                | mov     ebx, eax             |
|  movl    (%ecx),%eax               | mov     eax,[ecx]            |
|  movl    3(%ebx),%eax              | mov     eax,[ebx+3]          | 
|  movl    0x20(%ebx),%eax           | mov     eax,[ebx+20h]        |
|  addl    (%ebx,%ecx,0x2),%eax      | add     eax,[ebx+ecx*2h]     |
|  leal    (%ebx,%ecx),%eax          | lea     eax,[ebx+ecx]        |
|  subl    -0x20(%ebx,%ecx,0x4),%eax | sub     eax,[ebx+ecx*4h-20h] |

## 基本内联语法  

基本内联汇编的格式非常简单, 基本形式是   
```
asm("assembly code");
```
举个例子:  
```
asm("movl %ecx %eax"); /* moves the contents of ecx to eax */
__asm__("movb %bh (%eax)"); /*moves the byte from bh to the memory pointed by eax */
```
关键字```__asm__``` 和```asm```等价, 前者从代码规范上来说一般不容易和逻辑代码冲突(C++03标准开始明确规定__前缀为编译器保留关键字).   

如果我们有多行指令, 则每行用双引号引起来, 并添加指令后缀```\n\t```  例如:  
```
 __asm__ ("movl %eax, %ebx\n\t"
          "movl $56, %esi\n\t"
          "movl %ecx, $label(%edx,%ebx,$4)\n\t"
          "movb %ah, (%ebx)");
```

以上的汇编编写还存在一个问题, 即编译器对对我们嵌入的汇编代码带来的寄存器修改一无所知,  要么我们避免修改编译器用到的寄存器, 要么在修改前后做好恢复,  因此, 我们通常使用extended asm, 通过指定的规范, 编译器会正确的帮我们处理好这个问题.    

## 扩展汇编:  

在扩展汇编中, 我们可以指定操作数, 包括指定输入寄存器, 指定输出寄存器, 指定会被破坏的寄存器列表;  通过这些指定和规则约束, 编译器则会在汇编生成过程中避免使用到该类寄存器(最坏情况下编译器生成对应的压栈和恢复等操作), 以及对内联汇编选择合适的优化等, 我们则可以把精力放在我们需要关心的逻辑本身上.   
其基本格式为:   
```
asm ( assembler template 
    : output operands                  /* optional */
    : input operands                   /* optional */
    : list of clobbered registers      /* optional */
    );
```


* assembler template 汇编模版由汇编指令组成; 
* operands 每个操作数由一个 操作数约束 字符串来描述, 后面跟括号中的C表达式.   
* 使用冒号将汇编程序模版和后面的输出操作数分开, 后面可选operands相同, 如果没有更多内容则可以简略(中间不可省略)   
* 操作数的总数有限制 (约为10个或者为设备描述的最大个数决定)   

举例如下:  
```
asm ("cld\n\t"
    "rep\n\t"
    "stosl"
    : /* no output registers */
    : "c" (count), "a" (fill_value), "D" (dest)
    : "%ecx", "%edi" 
    );
```


完整的描述为
>  输入:  从C/C++的4字节变量fill_value中读取数据存入寄存器%eax, count存入%ecx, dest存储%edi  

>  执行:  
  > cld使DF复位为0: 设置stosl保存eax值后的偏移方向为自增  
  > rep指令则重复后续单个指令```(%ecx)```次   
  > stosl 将eax中的值保存到ES:EDI指向的地址中, 如果DF=0则自增4字节, 如果DF=1(std)则自减4字节. (l后缀为4字节 q为8字节)    

> 输出: 没有输出   

> 破坏清单: 显式声明%ecx和%edi是被修改使用的寄存器    


再举个例子: 可变寄存器使用  
```
int a=10, b;
asm ("movl %1, %%eax; 
        movl %%eax, %0;"
        :"=r"(b)        /* output */
        :"r"(a)         /* input */
        :"%eax"         /* clobbered register */
        );       
```
赋值a给b;   
r 是操作数的约束, 即告诉GCC可以使用任何寄存器.   
eax 需要在这里显式声明   



### assembler template 汇编模板  
汇编器模板包含插入到C程序内部的汇编指令集  
格式如下:  
* 每条汇编指令都应该用双引号引起来 或者整个指令组都应该用双引号引起来  
* 每条汇编指令还应以定界符结尾: 
  * 有效的定界符是换行符(\n)和分号(;);  
  * '\n'后可以跟一个制表符'\t' 
  * **与C/C++表达式相对应的操作数**由%0, %1 ...等表示   
  

### operands 操作数  
C/C++表达式用作'asm'中汇编指令的操作数  
* 每个操作数首先被写成双引号中的操作数约束(operand constraint), 对于输出操作数还有一个约束修饰符'='  
* 然后后面跟随代表操作数的C/C++表达式  
* "约束 constraint" 主要用于确定操作数的寻址模式, 还用于指定要使用的寄存器.  (文后有对应常用constraint的表格)   
* 如果使用多个操作数, 以逗号','分隔   
* 在汇编模版中, 每个操作数均由数字引用. 编号方法如下: 如果一共有N个操作数, 包括输入和输出, 也包括指定寄存器, 第一个为0, 按书写顺序递增;   
* 输出操作数表达式必须为左值  输入操作数不受此限制  
* 在输入输出中出现的寄存器属于隐式破坏声明, 不比添加到破坏清单内.  

举几个例子:   
将数字乘以5  
```
asm ("leal (%1,%1,4), %0"
        : "=r" (five_times_x)
        : "r" (x) 
        );
```

输入和输出使用同一个寄存器(数字约束)
```
asm ("leal (%0,%0,4), %0"
        : "=r" (five_times_x)
        : "0" (x) 
        );
```

输入输出使用同一寄存器并指定  
```
        asm ("leal (%%ecx,%%ecx,4), %%ecx"
             : "=c" (x)
             : "c" (x) 
             );
```


### clobber-list 破坏清单  

我们必须在clobber-list中列出那些可能被指令破坏的寄存器   即asm函数中第三个':'之后的字段   
其目的是为了通知gcc我们将自己使用和修改它们 因此gcc不会假定它加载到这些寄存器中的值将是有效的.   
在这里不需要也不应该列出输入和输出寄存器, 因为gcc'知道'. 而在汇编模版中的汇编指令隐式或者显式使用了其他寄存器 则必须在此列出.   
如果我们的指令不可预测的方式修改了内存, 那么需要在clobber-list中添加'memory'.  gcc将不能在整个汇编程序中将内存缓存到寄存器中;   
如果受影响的内存未在输入和输出中列出, 那么我们还必须添加volatile关键字.   
如果指令可能更改了条件代码寄存器CCR 那么需要添加'cc'  

### __volatile__  
```
__asm__ __volatile__ ( ... : ... : ... : ...);
__asm__ __volatile__ ( ... : ... : ... : ...);
```

如果汇编语句必须在放置它的位置执行 (即 为了优化而不能从循环中移出), 则将关键字volatile放在asm之后和()之前   
如果不是确定需要volatile则不要添加, 因为会损失一些可能的性能上的优化   


### 常用约束  
