---
title: ELF文件的SECTIO分析    
date: 2019-11-09
categories: develop 
author: yawei.zhang 
---

### 目录  

---  

<!-- TOC -->

- [目录](#目录)
- [ELF文件类型和描述](#elf文件类型和描述)
  - [文件类型](#文件类型)
  - [链接器视图(编译器 汇编器 链接器)](#链接器视图编译器-汇编器-链接器)
  - [加载器视图 (系统加载器)](#加载器视图-系统加载器)
  - [基本测试命令](#基本测试命令)
  - [基础术语知识](#基础术语知识)
    - [目标文件格式的比较和说明](#目标文件格式的比较和说明)
    - [其他词汇说明](#其他词汇说明)
- [可重定位文件](#可重定位文件)
  - [lib.cpp片段分析](#libcpp片段分析)
  - [so.cpp片段分析](#socpp片段分析)

<!-- /TOC -->

### ELF文件类型和描述  

---  

(Executable and Linking Format) (可执行可链接格式) 文件    
#### 文件类型
* 可重定位文件  (relocatable file)  
  * 由源文件编译而成但是还没有链接成可执行文件, 扩展名通常为.o  通常'目标文件(object file)'  用于与其他目标文件进行链接成可执行文件或者动态链接库.  
  * 可重定位是指 对外部符号的访问会进行标记, 在链接时候会重写这部分访问(操作数)重定位到真正的位置上.  
  * 重定位因为存在该修补 则有以下作用:  
    * 重定位在执行时是直接使用真实位置 没有其他过程 性能非常好   
    * 链接共享库的时候如果需要确定地址和修补, 则还需要保证多个共享库的地址不可以重叠, 在32位下这种保证会很容易用尽虚拟(地址)空间  
    * 重定位需要修改代码段, 从而破坏'代码段'只读属性, 如果在链接阶段无法完成重定位, 则只能放在加载过程完成, 这样会导致'无法实现真正的代码共享' .  比如所有进程使用的相同so文件在内存中实际上只有一份就是依赖于so的代码段只读且一致这个原则上的.  

* 共享目标文件(shared object file)，即动态连接库文件 它在以下两种情况下被使用
  * 在链接过程中与其它动态链接库或可重定位文件一起构建新的目标文件
  * 在可执行文件被加载的过程中 被动态链接到新的进程中 成为运行代码的一部分  
  
* 可执行文件(executable file)，经过连接的，可以执行的程序文件。  
          
* coredump文件 核心转储  

<!-- more -->
#### 链接器视图(编译器 汇编器 链接器)   
链接器关心的内容   
| LINKING VIEW 
| -
| ELF HEADER
| PROGRAM HEADER TABLE OPTIONAL 
| SECTION 1  .text
| SECTION 2  .data
| SECTION n ...
| SECTION HEADER TABLE  

#### 加载器视图 (系统加载器) 
加载器关心的内容 
| EXECUTION VIEW 
| - 
| ELF HEADER
| PROGRAM HEADER TABLE 
| SEGMENT 1 
| SEGMENT 2 
| SEGMENT N ...
| SECTION HEADER TABLE OPTIONAL 

#### 基本测试命令     
```
ldd - print shared library dependencies  
readelf -a 查看elf文件
objdump -S 查看汇编码

gcc -g -c lib.cpp  编译目标文件  
gcc -g -c -fpic lib.cpp  启用地址无关代码选项来编译目标文件   
ar -cr liblib.a  lib.o  打包目标文件到静态库   
g++ -g -fPIC -shared so.cpp -o so.so  启用地址无关代码的链接选项和编译选项来编译共享库   
g++ -g -fpie -fPIE -pie -o main  lib.o libso.so 

export LD_LIBRARY_PATH="./" 设置临时的共享库搜索路径  

PIC和PIE都用于编译地址无关代码, PIE假定了最终链接的目标是可执行文件.  
pie是链接选项 用于生成DYN类型的可执行文件.   

```

#### 基础术语知识   
##### 目标文件格式的比较和说明    
* a.out 文件格式  
  * 旧版unix like系统(包括linux1.2以及之前的版本)中用于可执行文件 目标代码 共享库等的文件格式, 后续基本被ELF取代   
  * 后续习惯性把a.out作为可执行文件的默认输出名, 即使格式不是a.out   
  * stabs 是一种调试数据格式, 用来存储程序信息供符号级/源代码级的调试器用, 因该信息存储在符号表的一个特殊条目中因此得名为刺 (条目 stabs)  该格式除了完成对a.out的调试信息支持, 还用于COFF ELF的变体中 .   

* ELF 文件格式  
  * Executable and Linking Format 可执行可链接的文件格式 
  * 原名 Extensible Linking Format  可扩展可链接的文件格式
  * DWARF 标准化的调试数据格式 为ELF的补语  
    * 该符号是一个历史遗留的名称, 没有正式含义, 定义为"标准化的调试数据格式", 被广泛使用.   
      * DWARF使用DIE(调试信息条目)的数据结构来表示每个变量, 类型, 过程, 具有标签,属性(键值对).  
    * DIE可以嵌套形成树结构.  
      * DIE属性可以引用树中任何位置的另外一个DIE  
        * 例如: 表示变量的DIE有一个DW_AT_type条目，该条目指向描述变量类型的DIE  

* COFF 文件格式    
  * Common Object File Format  通用对象文件格式  类似ELF a.out  
  * COFF文件的出现主要是因为a.out无法充分支持共享库, 包括外部格式标识, 显式地址链接.  
  * COFF的设计过于局限和不完整, 导致实际的实现必然违反COFF标准, 目前仍然使用的较为广泛的是windows的PE版本 
  * COFF对a.out的主要改进是在目标文件中引入了多个命名节  不同的对象文件可能具有不同数量和类型的节  
  * 文件的第一个字节将被加载的虚拟地址称为映像基地址 文件的其余部分不一定要装入一个连续的块中 而是要装入不同的部分中  


| Format name | Operating system                                  | Filename extension | Explicit processor declarations | Arbitrary sections | Metadata[a] | Digital signature | String table | Symbol table | 64-bit    | Fat binaries    | Can contain icon |
| ----------- | ------------------------------------------------- | ------------------ | ------------------------------- | ------------------ | ----------- | ----------------- | ------------ | ------------ | --------- | --------------- | ---------------- |
| 格式名      | 操作系统                                          | 文件名扩展         | 显式处理器声明                  | 任意节             | 元数据[a]   | 数字签名          | 字符串表     | 符号表       | 64位      | fat格式文件支持 | 包含图标         |
| a.out       | Unix-like                                         | none               | No                              | No                 | No          | No                | Yes[1]       | Yes[1]       | Extension | No              | No               |
| COFF        | Unix-like                                         | none               | Yes by file                     | Yes                | No          | No                | Yes          | Yes          | Extension | No              | No               |
| XCOFF       | IBM AIX, BeOS, "classic" Mac OS                   | none               | Yes by file                     | Yes                | No          | No                | Yes          | Yes[2]       | Yes       | No              | No               |
| ELF         | Unix-like, OpenVMS, BeOS from R4 onwards, Haiku   | none               | Yes by file                     | Yes                | Yes         | Yes[3]            | Yes          | Yes[4]       | Yes       | Extension[5]    | Extension[6]     |
| PE          | Windows, ReactOS, HX DOS Extender, BeOS (R3 only) | .EXE               | Yes by file                     | Yes                | Yes         | Yes[10]           | Yes          | Yes          | No        | No              | Yes              |

##### 其他词汇说明  
* ELF header 文件头   
  * ELF文件的组成描述
  * 结构
    * 版本信息等    
    * ELF文件类型
      * ET_REL 可重定位文件 .o .a
      * ET_DYN 可共享文件 .so  PIE版本的可执行文件   
      * ET_EXEC 可执行文件   
      * ET_CORE 核心转储  coredump
    * 入口点地址  0x400510  
    * ELF header大小  
    * PROGRAM HEADERS大小和数量
    * SECTION HEADERS大小和数量  
    * Section header string table index 字符串表索引节头位置(.shstrtab) 
* section header SH 节头  
  * .text section 里装载了可执行代码
  * .data section 里面装载了被初始化的数据
  * .bss section 里面装载了未被初始化或者初始化为0的数据  
    * bss 不占据ELF文件的空间 因为没有内容只有空间大小和类型信息  
  
  * .commont 开发环境的时候使用的GCC版本信息   
  * .shstrtab 指的是section header string table 保存了各个section的名字   
  * .strtab 或者 .dynstr section 里面装载了字符串信息 字符串和符号的区别是 字符串是程序执行内容中, 符号是代码符号.  
  * .rodata 字符串常量  
  * .eh_frame 其内部存放了以DWARF格式保存的一些调试信息 格式与 .debug_frame 是很相似的（不完全相同）.  
  
  * .dynsym  动态库的符号表  
    * 动态加载需要的符号表(动态库)  
  * .symtab section 符号表(全量)   
    * 包括了.strtab里面定义的符号 每个符号对应的符号表是一个Elf64_Symbol结构体 除了包含.strtab外 符号表中还包含了一些section的符号表条目 
    * Value 符号所在的section偏移, 比如代码段的相对偏移地址, 数据段的相对偏移地址    
    * Size 大小,  如果是变量则是变量的size, 如果是函数则是指令的行数  
    * Type 符号的类型 NOTYPE或者UND代表是外部符号, FUNC函数, OBJECT数据, SECTION 节 
      * 如果是so/exe则还有bss data等字段    
    * Bind 绑定类型 LOCAL GLOBAL  
    * vis  
    * NDX
    * NAME 符号名  

  * .rel 打头的 sections 里面装载了重定位条目   
    * 在最终二进制文件中 使用"符号的地址"在此目标文件中的"偏移量"处修补该值   


    * .rel.text RELOCATION RECORDS FOR [.text] (object file)包含了代码段中引用的函数和全局变量的重定位条目 包括调用当前编译单元的
      * Offset 偏移地址 代码段中要修改掉的地址  
      * Type 类型 不启用PIC的一般是PC32 启用后如下
        * PLT32 函数符号 外部或者内部  
        * GOT PC RELX 全局变量符号  包括外部和内部  
      * VALUE 符号名和加数  



    * .rela.eh_frame RELOCATION RECORDS FOR [.eh_frame](object file)  eh_frame 的重定位信息    
      * 在编译成object file的过程中, 该section提供了当前编译单元所定义的函数符号以及符号所在代码段的偏移位置.  
      * OFFSET 当前函数在代码段中的开始位置  
      * TYPE   PC32 本地实现  
      * VALUE  符号表中的类型名以及符号的Value位置   



    * .rel.plt (动态库或者EXE)节的每个表项对应了所有外部过程调用符号的重定位信息  
      * 主要是 JUMP_SLOT 类型的重定位项  
        * 重定位只需将符号地址填入被修正的内存即可
      * 比如定义了一个函数test, 所有call test的地方都存在这个位置  
    * .rel.dyn section (动态库或者EXE)的每个表项对应了除了外部过程调用的符号以外的所有重定位对象(一般是数据)  
      * 主要是 GLOB_DAT 类型的重定位项
        * 重定位只需将符号地址填入被修正的内存即可
      * 比如extern来自so文件的全局静态变量  
      * 或者开启pic后自己的全局静态变量  
  
    * 类型  
      * GOT Global Offset Table  全局偏移表  
      * PC  program counter relative displacement  程序计数的相对偏移/ IP指令的操作数修改   
      * PLT procedure linkage table  过程链接表
      * R_386_GOT32：该重定位类型计算从全局偏移表（global offset table）的基址到符号所在的全局偏移表表项的距离，并且通知链接编辑器建立全局偏移表。（G+A-P）
      * R_386_PLT32：该重定位类型计算符号的过程链接表表项地址，并且通知链接编辑器构建过程链接表。（L+A-P）
      * R_386_COPY：链接编辑器创建此重定位类型是用于动态链接的。它的r_offset成员对应一个可写segment中的位置。符号表索引指定了一个在当前目标文件和共享目标文件中都存在的符号。在执行期间，动态链接器拷贝与共享目标的符号相关的数据到偏移指定的位置。（none）
      * R_386_GLOB_DAT：用于给指定符号的地址设置一个全局偏移表表项。该特殊重定位类型确定符号和全局偏移表项之间的对应关系。（S）
      * R_386_JMP_SLOT：链接编辑器创建此重定位类型是用于动态链接的，它的偏移给出了过程链接表表项的位置。动态链接器通过修改过程链接表表项，把控制权传递给指定符号的地址，参见第二章“过程链接表”一节。（S）
      * R_386_RELATIVE：链接编辑器创建此重定位类型是用于动态链接的，它的偏移成员给出了共享目标中的一个位置，这个位置包含了一个表示相对地址的值。动态链接器通过把共享目标被加载的虚拟地址与相对地址相加，计算出对应的虚拟地址。此重定位类型的重定位表项必须把符号表索引置为0。（B+A）
      * R_386_GOTOFF：此类型的重定位计算符号值和全局偏移表地址的差值，并且通知链接编辑器构建全局偏移表。（S+A-GOT）
      * R_386_GOTPC：此类型类似于R_386_PC32。只是它在计算中使用全局偏移表的地址。这种类型的重定位引用的通常是_GLOBAL_OFFSET_TABLE_DE类型的符号，并且通知链接编辑器构建全局偏移表。（GOT+A-P）****

  * 这些条目给链接的时候需要和其他可重定位文件或者库的对应的section合并时提供了必要的信息  


* program header PH 程序头
  * segment信息
* base address             基地址       
* dynamic linker           动态连接器   
* dynamic linking          动态连接     
* global offset table      全局偏移量表 
* hash table               哈希表       
* initialization function  初始化函数   
* link editor              连接编辑器   
* object file              目标文件     
* procedure linkage table  函数连接表   
* program header           程序头       
* program header table     程序头表     
* program interpreter      程序解析器   
* relocation               重定位       
* shared object            共享目标     
* section                  节           
* section header           节头         
* section header table     节头表       
* segment                  段           
* string table             字符串表     
* symbol table             符号表       
* termination function     终止函数     




### 可重定位文件    

---  
 




* 注：各个段之间并未严格的首位相接，考虑到对齐的因素，他们之间会存在”空洞”（如图中.shstrtab段和Section Header Table之间的padding分区）；


#### lib.cpp片段分析  

lib.cpp
```
int g_static_lib_bss = 0;
int g_static_lib_data = 0xff1234ff;
int lib_func(int a, int b)
{
  return a+b;
}
```
通过命令编译出目标文件lib.o和分析数据
```
g++ -c -fpic lib.cpp -o lib.pic.o
g++ -c       lib.cpp -o lib.npic.o  
g++ -c -fpie -pie lib.cpp -o lib.pie.o
readelf -a lib.npic.o
readelf -a lib.pic.o
objdump -S lib.npic.o
objdump -S lib.pic.o
```

lib.cpp无论是pie选项还是pic, 编译的结果完全一致 

```
ELF 头：
  ABI 版本:                          0
  类型:                              REL (可重定位文件)

重定位节 '.rela.eh_frame' 位于偏移量 0x1f0 含有 1 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000000020  000200000002 R_X86_64_PC32     0000000000000000 .text + 0

Symbol table '.symtab' contains 11 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS lib.cpp
     8: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    3 g_static_lib_bss
     9: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    2 g_static_lib_data
    10: 0000000000000000    20 FUNC    GLOBAL DEFAULT    1 _Z8lib_funcii


0000000000000000 <_Z8lib_funcii>:
   0:   55                      push   %rbp
   1:   48 89 e5                mov    %rsp,%rbp
   4:   89 7d fc                mov    %edi,-0x4(%rbp)
   7:   89 75 f8                mov    %esi,-0x8(%rbp)
   a:   8b 55 fc                mov    -0x4(%rbp),%edx
   d:   8b 45 f8                mov    -0x8(%rbp),%eax
  10:   01 d0                   add    %edx,%eax
  12:   5d                      pop    %rbp
  13:   c3                      retq   
```


#### so.cpp片段分析  
so.cpp
```
int lib_func(int a, int b);
int so_func(int a, int b)
{
  int ret = lib_func(a, b);
  return ret;
}
```
通过命令编译出目标文件so.o和分析数据
```
g++ -c -fpic so.cpp -o so.pic.o
g++ -c       so.cpp -o so.npic.o  
readelf -a so.npic.o
readelf -a so.pic.o
objdump -S so.npic.o
objdump -S so.pic.o
```

so.cpp的两个object文件的汇编码一致, 但是readelf中的section不同 主要区别如下:
* no -fpic选项的目标文件中 .rela.text 的两个引用的符号类型是PC32  
*    -fpic选项的目标文件中 .rela.text 的两个引用的符号类型是PLT32  
*    -fpic选项的目标文件中 .symtab 的外部引用符号之前多了一个_GLOBAL_OFFSET_TABLE_  即GOT表的符号和地址信息

* .got.plt .got在共享文件或者可执行文件中  
* GOT是 GLOBAL_OFFSET_TABLE  全局偏移表  GOT用来做在链接时建立数据和地址的重定位
  * ELF的数据段里面建立一个指向这些变量的指针数组 当指令中需要访问外部变量时 会先找到GOT 然后根据GOT中变量所对应的项找到变量的目标地址
  * 链接器在装载模块时会查找每个变量所在的地址 然后填充GOT中每个项 由于GOT是放在数据段的 所以每个进程可以有一个独立的副本  
  * GOT的意义是访问数据的时候通过GOT读表获取目标数据的地址, 而不是在链接或者加载时对目标代码进行修改(重定向)   
  * GOT延迟绑定 而不是load的时候一次性全部做好地址的绑定 减少加载时候的工作量
  * 通过GOT实现 代码应该始终是只读的 
  * 通过GOT可实现修改符号绑定顺序的能力  
* PLT 小型过程链接表存根(stub)进行, 如果plt有则直接使用没有则去找, 有的话则用存根ID去GOT中查找记录的地址 
  * 每个函数对应一个小的过程类似如下: 
    ```
    0000000000000690 <_Z13so_inner_funcii@plt>:
    690:   ff 25 8a 09 20 00       jmpq   *0x20098a(%rip)        # 201020 <_Z13so_inner_funcii@@Base+0x200870>
    696:   68 01 00 00 00          pushq  $0x1
    69b:   e9 d0 ff ff ff          jmpq   670 <.plt>
    ```

```
全局偏移量表(global offset table)在私有数据中包含绝对地址
出于方便共享和重用的考虑，目标文件中的很多内容是“位置无关”的，其映射到进程内存中的什么位置是不一定的，所以只适合使用相对地址，全局偏移量表是一个例外
在UNIX System V 环境下的动态连接过程中，got 表是必须的，它的实际内容和格式依处理器不同而不同。
总的来说，位置独立的代码不能含有绝对的虚拟地址。全局偏移量表选择了在私有数据中含有绝对地址，这种办法在没有牺牲位置独立性和可共享性的前提下保存了绝对地址。引用全局偏移量表的程序可以同时使用位置独立的地址和绝对地址，把位置无关的引用重定向到绝对地址上去。
一开始，全局偏移量表只包含其重定位项所要求的信息。当系统为可装载的目标文件创建了内存段之后，动态连接器处理重定位项，有些重定位项的类型为R_386_GLOB_DAT，它们指向全局偏移量表。动态连接器决定相应的符号值，计算其绝对地址，并且为内存段设置适当的值。尽管在连接编辑器创建目标文件的时候绝对地址还是未知的，但是动态连接器却知道所有内存段的地址，因此它可以计算所含有的所有符号的绝对地址。
如果一个程序要求直接访问符号的绝对地址，那么这个符号在全局偏移量表中就必须有一个对应的项。可执行文件和共享目标文件有各自的全局偏移量表，所以一个符号的地址可能会出现在多个表中。动态连接器会在程序开始执行之前，处理好所有全局偏移量表的重定位工作，所以在程序执行的时候，可以保证所有这些符号都有正确的绝对地址。
全局偏移量表的第 0 项是保留的，它用于持有动态结构的地址，由符号_DYNAMIC 引用。这样，其它程序，比如动态连接器就可以直接找到其动态结构，而不用借助重定位项。这对于动态连接器来说尤为重要，因为它必须在不依赖于其它程序重定位其内存镜像的情况下初始化自己。前面提到过，在 Intel 架构中，全局偏移量表中的第 1 项和第 2 项也是保留的，它们持有函数连接表的信息。
系统可能为同一个共享目标在不同的程序中选择不同的段地址；甚至也可能每次为同一个程序选择不同的地址。但是，在单次执行中，一旦一个进程的镜像建立起来之后，直到程序退出，内存段的地址都不会再改变了。
全局偏移量表的格式和解析方法是依处理器而不同的，就 Intel 架构而言，符号_GLOBAL_OFFSET_TABLE_会被用来访问此表。

extern Elf32_Addr _GLOBAL_OFFSET_TABLE_[];
符号_GLOBAL_OFFSET_TABLE_可能位于.got 节中部，所以它也接受负的数组索引值。
```
* PLT是 Procedure Link Table 程序链接表  PLT用来做在链接时建立符号和地址的重定位  
  * PLT的实现是延迟查找  






















