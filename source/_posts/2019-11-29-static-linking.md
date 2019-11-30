---
title: 静态链接过程    
date: 2019-11-29
categories: develop 
author: yawei.zhang 
---

### 目录  

---  

<!-- TOC -->

- [目录](#目录)
- [基本编译链接流程](#基本编译链接流程)
  - [测试源代码](#测试源代码)
  - [生成汇编代码 (从这里开始会有两个分支代码 NON-PIC 和 PIC对照)](#生成汇编代码-从这里开始会有两个分支代码-non-pic-和-pic对照)
    - [汇编代码 (相对位置版本)](#汇编代码-相对位置版本)
    - [汇编代码 (位置无关版本)](#汇编代码-位置无关版本)
  - [生成ELF的可重定位文件](#生成elf的可重定位文件)
    - [可重定向文件和汇编指令 (相对位置版本)](#可重定向文件和汇编指令-相对位置版本)
    - [可重定向文件和汇编指令 (位置无关版本)](#可重定向文件和汇编指令-位置无关版本)
  - [链接为可执行文件(或者共享库)](#链接为可执行文件或者共享库)
    - [可执行文件 (相对位置的非PIE(EXEC)版本)](#可执行文件-相对位置的非pieexec版本)
    - [可执行文件 (相对位置的PIE(DYN)版本)](#可执行文件-相对位置的piedyn版本)
    - [可执行文件 (位置无关的非PIE(EXEC)版本)](#可执行文件-位置无关的非pieexec版本)
    - [可执行文件 (位置无关的PIE(DYN)版本)](#可执行文件-位置无关的piedyn版本)

<!-- /TOC -->

### 基本编译链接流程   
* 编译并输出汇编代码  
  * g++ -S lib.cpp -o lib.s 
* 打包成ELF可重定位文件 ELF TYPE= ET_REL  即.o文件  
  * g++ -c lib.s -o lib.o 
* 链接到动态库或者可执行文件
  * g++ lib.o -o a.out   
  * g++ -shared lib.o -o a.out 

<!-- more -->
#### 测试源代码    
``` C++
int g_static_bss = 0;
int g_static_data = 182;
const int g_static_text = 1987;
int main_func(int a, int b)
{
   return a+b + g_static_text;
}


int main(int argc, char *argv[])
{
   int a = 0;
   g_static_bss = argc;
   a += main_func(g_static_bss, g_static_data);
   return a;
}
```

#### 生成汇编代码 (从这里开始会有两个分支代码 NON-PIC 和 PIC对照)    

在这段代码中 

* g_static_bss  
  * 为全局的符号(给链接器看到) 
  * 被放在.bss字段(未初始化数据段, Block Started by Symbol)中 
  * 占用4个字节  类型是object 初始化为0   
  * 4字节对齐  

* g_static_data  
  * 为全局的符号(给链接器看到) 
  * 被放在.data字段(数据段)中 
  * 占用4个字节  类型是object 初始化为182   
  * 4字节对齐  

* _ZL13g_static_text  
  * 为全局的符号(给链接器看到) 
  * 被放在.rodata字段(只读数据段)中 
  * 占用4个字节  类型是object 初始化为1987   
  * 4字节对齐  

* _Z9main_funcii  
  * 为全局的符号(给链接器看到) 
  * 被放在.text字段(代码段)中 
  * 占用4个字节  类型是function  

* main  
  * 为全局的符号(给链接器看到) 
  * 被放在.text字段(代码段)中 
  * 占用4个字节  类型是function  

* GOTPCREL 
  * PC-REL是指的位置相对代码   
  * 这里是指的走GOT表的位置相对代码   

* 在下面的对照中  对于全局符号的访问有如下区别
  * 访问全局对象时 PIC 版本会先从相对当前代码位置的GOT表中读取全局对象的地址到RAX 然后再读取其内容   
  * 非PIC版本则直接用记录好的地址读取其内容  


##### 汇编代码 (相对位置版本)
``` ARMASM
    .file    "test.cpp"
    .globl    g_static_bss
    .bss
    .align 4
    .type    g_static_bss, @object
    .size    g_static_bss, 4
g_static_bss:
    .zero    4
    .globl    g_static_data
    .data
    .align 4
    .type    g_static_data, @object
    .size    g_static_data, 4
g_static_data:
    .long    182
    .section    .rodata
    .align 4
    .type    _ZL13g_static_text, @object
    .size    _ZL13g_static_text, 4
_ZL13g_static_text:
    .long    1987
    .text
    .globl    _Z9main_funcii
    .type    _Z9main_funcii, @function
_Z9main_funcii:
.LFB0:
    .cfi_startproc
    pushq    %rbp
    .cfi_def_cfa_offset 16
    .cfi_offset 6, -16
    movq    %rsp, %rbp
    .cfi_def_cfa_register 6
    movl    %edi, -4(%rbp)
    movl    %esi, -8(%rbp)
    movl    -4(%rbp), %edx
    movl    -8(%rbp), %eax
    addl    %edx, %eax
    addl    $1987, %eax
    popq    %rbp
    .cfi_def_cfa 7, 8
    ret
    .cfi_endproc
.LFE0:
    .size    _Z9main_funcii, .-_Z9main_funcii
    .globl    main
    .type    main, @function
main:
.LFB1:
    .cfi_startproc
    pushq    %rbp
    .cfi_def_cfa_offset 16
    .cfi_offset 6, -16
    movq    %rsp, %rbp
    .cfi_def_cfa_register 6
    subq    $32, %rsp
    movl    %edi, -20(%rbp)
    movq    %rsi, -32(%rbp)
    movl    $0, -4(%rbp)
    movl    -20(%rbp), %eax
    movl    %eax, g_static_bss(%rip)
    movl    g_static_data(%rip), %edx
    movl    g_static_bss(%rip), %eax
    movl    %edx, %esi
    movl    %eax, %edi
    call    _Z9main_funcii
    addl    %eax, -4(%rbp)
    movl    -4(%rbp), %eax
    leave
    .cfi_def_cfa 7, 8
    ret
    .cfi_endproc
.LFE1:
    .size    main, .-main
    .ident    "GCC: (Debian 6.3.0-18+deb9u1) 6.3.0 20170516"
    .section    .note.GNU-stack,"",@progbits

```

##### 汇编代码 (位置无关版本) 
``` ARMASM
    .file    "test.cpp"
    .globl    g_static_bss
    .bss
    .align 4
    .type    g_static_bss, @object
    .size    g_static_bss, 4
g_static_bss:
    .zero    4
    .globl    g_static_data
    .data
    .align 4
    .type    g_static_data, @object
    .size    g_static_data, 4
g_static_data:
    .long    182
    .section    .rodata
    .align 4
    .type    _ZL13g_static_text, @object
    .size    _ZL13g_static_text, 4
_ZL13g_static_text:
    .long    1987
    .text
    .globl    _Z9main_funcii
    .type    _Z9main_funcii, @function
_Z9main_funcii:
.LFB0:
    .cfi_startproc
    pushq    %rbp
    .cfi_def_cfa_offset 16
    .cfi_offset 6, -16
    movq    %rsp, %rbp
    .cfi_def_cfa_register 6
    movl    %edi, -4(%rbp)
    movl    %esi, -8(%rbp)
    movl    -4(%rbp), %edx
    movl    -8(%rbp), %eax
    addl    %edx, %eax
    addl    $1987, %eax
    popq    %rbp
    .cfi_def_cfa 7, 8
    ret
    .cfi_endproc
.LFE0:
    .size    _Z9main_funcii, .-_Z9main_funcii
    .globl    main
    .type    main, @function
main:
.LFB1:
    .cfi_startproc
    pushq    %rbp
    .cfi_def_cfa_offset 16
    .cfi_offset 6, -16
    movq    %rsp, %rbp
    .cfi_def_cfa_register 6
    subq    $32, %rsp
    movl    %edi, -20(%rbp)
    movq    %rsi, -32(%rbp)
    movl    $0, -4(%rbp)
    movq    g_static_bss@GOTPCREL(%rip), %rax
    movl    -20(%rbp), %edx
    movl    %edx, (%rax)
    movq    g_static_data@GOTPCREL(%rip), %rax
    movl    (%rax), %edx
    movq    g_static_bss@GOTPCREL(%rip), %rax
    movl    (%rax), %eax
    movl    %edx, %esi
    movl    %eax, %edi
    call    _Z9main_funcii@PLT
    addl    %eax, -4(%rbp)
    movl    -4(%rbp), %eax
    leave
    .cfi_def_cfa 7, 8
    ret
    .cfi_endproc
.LFE1:
    .size    main, .-main
    .ident    "GCC: (Debian 6.3.0-18+deb9u1) 6.3.0 20170516"
    .section    .note.GNU-stack,"",@progbits
```

#### 生成ELF的可重定位文件

* .rela.text 重定位section
  * 包含了所有需要进行重定位的信息, 偏移量是相对于.text  类型则是注明了重定位的方式  


* .rela.eh_frame 重定位section  
* .symtab 符号表section  
  * Value 标记了符号所在的偏移地址 
  * SIZE 标记了代码或者变量占的大小  
  * Ndx 如果不在本编译单元 类型为NOTYPE Ndx为UND   
  * Bind 全局还是局部符号(是否链接器可见)  
    * rodata的符号为local是因为直接被编译到了代码中 
      * 例如g_static_text 1987 => ```add $0x7c3,%eax```

* .rela.eh_frame Call Frame Information 
  * 提供了异常的Stack Unwind 支持  
  * 这张表提供了'给定一个PC值, 可以查到上一个stack frame位置'
  * Stack Unwind 指从最內层函数呼叫堆栈开始，找到最外层
    * _Unwind_Backtrace() 
    * uw_frame_state_for() 
    * uw_update_context() 
    * uw_update_context_1()

* PC32 的PC是指的 program counter   在本文的汇编中对应寄存器的RIP 
* PC32 在重定位类型中代表相对指令位置的重定位
* PLT 则代表使用 过程链接表 进行重定位 (动态定位)   
* GOT 是全局偏移表  
* PGOT 是私有全局偏移表  

在这个过程中 
无论是PIC的PLT调用还是PC调用, 对于call 指令 他的操作数都是0 
无论是GOTPCREL还是PC 对全局对象符号的访问中 操作数也都是0  
在重定位节中标记了这些需要在链接过程中重建的具体位置和内容 


##### 可重定向文件和汇编指令 (相对位置版本)
``` ARMASM
重定位节 '.rela.text' 位于偏移量 0x2c8 含有 4 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000000034  000a00000002 R_X86_64_PC32     0000000000000000 g_static_bss - 4
00000000003a  000b00000002 R_X86_64_PC32     0000000000000000 g_static_data - 4
000000000040  000a00000002 R_X86_64_PC32     0000000000000000 g_static_bss - 4
000000000049  000c00000002 R_X86_64_PC32     0000000000000000 _Z9main_funcii - 4

重定位节 '.rela.eh_frame' 位于偏移量 0x328 含有 2 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000000020  000200000002 R_X86_64_PC32     0000000000000000 .text + 0
000000000040  000200000002 R_X86_64_PC32     0000000000000000 .text + 19

The decoding of unwind sections for machine type Advanced Micro Devices X86-64 is not currently supported.

Symbol table '.symtab' contains 14 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS test.cpp
     2: 0000000000000000     0 SECTION LOCAL  DEFAULT    1 
     3: 0000000000000000     0 SECTION LOCAL  DEFAULT    3 
     4: 0000000000000000     0 SECTION LOCAL  DEFAULT    4 
     5: 0000000000000000     0 SECTION LOCAL  DEFAULT    5 
     6: 0000000000000000     4 OBJECT  LOCAL  DEFAULT    5 _ZL13g_static_text
     7: 0000000000000000     0 SECTION LOCAL  DEFAULT    7 
     8: 0000000000000000     0 SECTION LOCAL  DEFAULT    8 
     9: 0000000000000000     0 SECTION LOCAL  DEFAULT    6 
    10: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    4 g_static_bss
    11: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    3 g_static_data
    12: 0000000000000000    25 FUNC    GLOBAL DEFAULT    1 _Z9main_funcii
    13: 0000000000000019    60 FUNC    GLOBAL DEFAULT    1 main

.text
0000000000000000 <_Z9main_funcii>:
   0:   55                      push   %rbp
   1:   48 89 e5                mov    %rsp,%rbp
   4:   89 7d fc                mov    %edi,-0x4(%rbp)
   7:   89 75 f8                mov    %esi,-0x8(%rbp)
   a:   8b 55 fc                mov    -0x4(%rbp),%edx
   d:   8b 45 f8                mov    -0x8(%rbp),%eax
  10:   01 d0                   add    %edx,%eax
  12:   05 c3 07 00 00          add    $0x7c3,%eax
  17:   5d                      pop    %rbp
  18:   c3                      retq   

0000000000000019 <main>:
  19:   55                      push   %rbp
  1a:   48 89 e5                mov    %rsp,%rbp
  1d:   48 83 ec 20             sub    $0x20,%rsp
  21:   89 7d ec                mov    %edi,-0x14(%rbp)
  24:   48 89 75 e0             mov    %rsi,-0x20(%rbp)
  28:   c7 45 fc 00 00 00 00    movl   $0x0,-0x4(%rbp)
  2f:   8b 45 ec                mov    -0x14(%rbp),%eax
  32:   89 05 00 00 00 00       mov    %eax,0x0(%rip)        # 38 <main+0x1f>
  38:   8b 15 00 00 00 00       mov    0x0(%rip),%edx        # 3e <main+0x25>
  3e:   8b 05 00 00 00 00       mov    0x0(%rip),%eax        # 44 <main+0x2b>
  44:   89 d6                   mov    %edx,%esi
  46:   89 c7                   mov    %eax,%edi
  48:   e8 00 00 00 00          callq  4d <main+0x34>
  4d:   01 45 fc                add    %eax,-0x4(%rbp)
  50:   8b 45 fc                mov    -0x4(%rbp),%eax
  53:   c9                      leaveq 
  54:   c3                      retq   
```


##### 可重定向文件和汇编指令 (位置无关版本)
``` ARMASM
重定位节 '.rela.text' 位于偏移量 0x300 含有 4 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000000032  000a0000002a R_X86_64_REX_GOTP 0000000000000000 g_static_bss - 4
00000000003e  000b0000002a R_X86_64_REX_GOTP 0000000000000000 g_static_data - 4
000000000047  000a0000002a R_X86_64_REX_GOTP 0000000000000000 g_static_bss - 4
000000000052  000c00000004 R_X86_64_PLT32    0000000000000000 _Z9main_funcii - 4

重定位节 '.rela.eh_frame' 位于偏移量 0x360 含有 2 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000000020  000200000002 R_X86_64_PC32     0000000000000000 .text + 0
000000000040  000200000002 R_X86_64_PC32     0000000000000000 .text + 19

The decoding of unwind sections for machine type Advanced Micro Devices X86-64 is not currently supported.

Symbol table '.symtab' contains 15 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS test.cpp
     2: 0000000000000000     0 SECTION LOCAL  DEFAULT    1 
     3: 0000000000000000     0 SECTION LOCAL  DEFAULT    3 
     4: 0000000000000000     0 SECTION LOCAL  DEFAULT    4 
     5: 0000000000000000     0 SECTION LOCAL  DEFAULT    5 
     6: 0000000000000000     4 OBJECT  LOCAL  DEFAULT    5 _ZL13g_static_text
     7: 0000000000000000     0 SECTION LOCAL  DEFAULT    7 
     8: 0000000000000000     0 SECTION LOCAL  DEFAULT    8 
     9: 0000000000000000     0 SECTION LOCAL  DEFAULT    6 
    10: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    4 g_static_bss
    11: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    3 g_static_data
    12: 0000000000000000    25 FUNC    GLOBAL DEFAULT    1 _Z9main_funcii
    13: 0000000000000019    69 FUNC    GLOBAL DEFAULT    1 main
    14: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND _GLOBAL_OFFSET_TABLE_

.text
0000000000000000 <_Z9main_funcii>:
   0:   55                      push   %rbp
   1:   48 89 e5                mov    %rsp,%rbp
   4:   89 7d fc                mov    %edi,-0x4(%rbp)
   7:   89 75 f8                mov    %esi,-0x8(%rbp)
   a:   8b 55 fc                mov    -0x4(%rbp),%edx
   d:   8b 45 f8                mov    -0x8(%rbp),%eax
  10:   01 d0                   add    %edx,%eax
  12:   05 c3 07 00 00          add    $0x7c3,%eax
  17:   5d                      pop    %rbp
  18:   c3                      retq   

0000000000000019 <main>:
  19:   55                      push   %rbp
  1a:   48 89 e5                mov    %rsp,%rbp
  1d:   48 83 ec 20             sub    $0x20,%rsp
  21:   89 7d ec                mov    %edi,-0x14(%rbp)
  24:   48 89 75 e0             mov    %rsi,-0x20(%rbp)
  28:   c7 45 fc 00 00 00 00    movl   $0x0,-0x4(%rbp)
  2f:   48 8b 05 00 00 00 00    mov    0x0(%rip),%rax        # 36 <main+0x1d>
  36:   8b 55 ec                mov    -0x14(%rbp),%edx
  39:   89 10                   mov    %edx,(%rax)
  3b:   48 8b 05 00 00 00 00    mov    0x0(%rip),%rax        # 42 <main+0x29>
  42:   8b 10                   mov    (%rax),%edx
  44:   48 8b 05 00 00 00 00    mov    0x0(%rip),%rax        # 4b <main+0x32>
  4b:   8b 00                   mov    (%rax),%eax
  4d:   89 d6                   mov    %edx,%esi
  4f:   89 c7                   mov    %eax,%edi
  51:   e8 00 00 00 00          callq  56 <main+0x3d>
  56:   01 45 fc                add    %eax,-0x4(%rbp)
  59:   8b 45 fc                mov    -0x4(%rbp),%eax
  5c:   c9                      leaveq 
  5d:   c3                      retq 
```

#### 链接为可执行文件(或者共享库)  

在链接为目标文件时, 会合并处理每个目标文件, 生成plt代码 确定GOT(PGOT)的相对位置等  

在相对位置的两个版本中均可以看到对全局符号的访问均正确填充了相对位移  

PIE版本的区别主要是PIE使用了相对位置 连ELF类型都变成了DYN   
非PIE版本则使用了绝对位置 
测试代码没有调用外部函数符号 所以在PIC版本的汇编指令中并没有看到PLT指令

##### 可执行文件 (相对位置的非PIE(EXEC)版本)
``` ARMASM
重定位节 '.rela.dyn' 位于偏移量 0x388 含有 2 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000600ff0  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.2.5 + 0
000000600ff8  000200000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0

The decoding of unwind sections for machine type Advanced Micro Devices X86-64 is not currently supported.

Symbol table '.dynsym' contains 3 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@GLIBC_2.2.5 (2)
     2: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__

Symbol table '.symtab' contains 65 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000400238     0 SECTION LOCAL  DEFAULT    1 
     2: 0000000000400254     0 SECTION LOCAL  DEFAULT    2 
     3: 0000000000400274     0 SECTION LOCAL  DEFAULT    3 
     4: 0000000000400298     0 SECTION LOCAL  DEFAULT    4 
     5: 00000000004002b8     0 SECTION LOCAL  DEFAULT    5 
     6: 0000000000400300     0 SECTION LOCAL  DEFAULT    6 
     7: 0000000000400360     0 SECTION LOCAL  DEFAULT    7 
     8: 0000000000400368     0 SECTION LOCAL  DEFAULT    8 
     9: 0000000000400388     0 SECTION LOCAL  DEFAULT    9 
    10: 00000000004003b8     0 SECTION LOCAL  DEFAULT   10 
    11: 00000000004003d0     0 SECTION LOCAL  DEFAULT   11 
    12: 00000000004005a4     0 SECTION LOCAL  DEFAULT   12 
    13: 00000000004005b0     0 SECTION LOCAL  DEFAULT   13 
    14: 00000000004005b8     0 SECTION LOCAL  DEFAULT   14 
    15: 00000000004005f8     0 SECTION LOCAL  DEFAULT   15 
    16: 0000000000600e18     0 SECTION LOCAL  DEFAULT   16 
    17: 0000000000600e20     0 SECTION LOCAL  DEFAULT   17 
    18: 0000000000600e28     0 SECTION LOCAL  DEFAULT   18 
    19: 0000000000600e30     0 SECTION LOCAL  DEFAULT   19 
    20: 0000000000600ff0     0 SECTION LOCAL  DEFAULT   20 
    21: 0000000000601000     0 SECTION LOCAL  DEFAULT   21 
    22: 0000000000601018     0 SECTION LOCAL  DEFAULT   22 
    23: 000000000060102c     0 SECTION LOCAL  DEFAULT   23 
    24: 0000000000000000     0 SECTION LOCAL  DEFAULT   24 
    25: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    26: 0000000000600e28     0 OBJECT  LOCAL  DEFAULT   18 __JCR_LIST__
    27: 0000000000400410     0 FUNC    LOCAL  DEFAULT   11 deregister_tm_clones
    28: 0000000000400450     0 FUNC    LOCAL  DEFAULT   11 register_tm_clones
    29: 0000000000400490     0 FUNC    LOCAL  DEFAULT   11 __do_global_dtors_aux
    30: 000000000060102c     1 OBJECT  LOCAL  DEFAULT   23 completed.6972
    31: 0000000000600e20     0 OBJECT  LOCAL  DEFAULT   17 __do_global_dtors_aux_fin
    32: 00000000004004b0     0 FUNC    LOCAL  DEFAULT   11 frame_dummy
    33: 0000000000600e18     0 OBJECT  LOCAL  DEFAULT   16 __frame_dummy_init_array_
    34: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS test.cpp
    35: 00000000004005b4     4 OBJECT  LOCAL  DEFAULT   13 _ZL13g_static_text
    36: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    37: 00000000004006f8     0 OBJECT  LOCAL  DEFAULT   15 __FRAME_END__
    38: 0000000000600e28     0 OBJECT  LOCAL  DEFAULT   18 __JCR_END__
    39: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS 
    40: 00000000004005b8     0 NOTYPE  LOCAL  DEFAULT   14 __GNU_EH_FRAME_HDR
    41: 0000000000600e30     0 OBJECT  LOCAL  DEFAULT   19 _DYNAMIC
    42: 0000000000600e20     0 NOTYPE  LOCAL  DEFAULT   16 __init_array_end
    43: 0000000000600e18     0 NOTYPE  LOCAL  DEFAULT   16 __init_array_start
    44: 0000000000601000     0 OBJECT  LOCAL  DEFAULT   21 _GLOBAL_OFFSET_TABLE_
    45: 0000000000601028     4 OBJECT  GLOBAL DEFAULT   22 g_static_data
    46: 000000000060102c     0 NOTYPE  GLOBAL DEFAULT   22 _edata
    47: 0000000000601018     0 NOTYPE  WEAK   DEFAULT   22 data_start
    48: 00000000004005b0     4 OBJECT  GLOBAL DEFAULT   13 _IO_stdin_used
    49: 00000000004004d6    25 FUNC    GLOBAL DEFAULT   11 _Z9main_funcii
    50: 00000000004004ef    60 FUNC    GLOBAL DEFAULT   11 main
    51: 0000000000601020     0 OBJECT  GLOBAL HIDDEN    22 __dso_handle
    52: 00000000004005a4     0 FUNC    GLOBAL DEFAULT   12 _fini
    53: 0000000000400400     2 FUNC    GLOBAL HIDDEN    11 _dl_relocate_static_pie
    54: 00000000004003d0    43 FUNC    GLOBAL DEFAULT   11 _start
    55: 00000000004003b8     0 FUNC    GLOBAL DEFAULT   10 _init
    56: 0000000000601030     0 OBJECT  GLOBAL HIDDEN    22 __TMC_END__
    57: 0000000000601018     0 NOTYPE  GLOBAL DEFAULT   22 __data_start
    58: 0000000000601038     0 NOTYPE  GLOBAL DEFAULT   23 _end
    59: 000000000060102c     0 NOTYPE  GLOBAL DEFAULT   23 __bss_start
    60: 0000000000400530   101 FUNC    GLOBAL DEFAULT   11 __libc_csu_init
    61: 0000000000601030     4 OBJECT  GLOBAL DEFAULT   23 g_static_bss
    62: 00000000004005a0     2 FUNC    GLOBAL DEFAULT   11 __libc_csu_fini
    63: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@@GLIBC_
    64: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__



.text
00000000004003b8 <_init>:
  4003b8:       48 83 ec 08             sub    $0x8,%rsp
  4003bc:       48 8b 05 35 0c 20 00    mov    0x200c35(%rip),%rax        # 600ff8 <__gmon_start__>
  4003c3:       48 85 c0                test   %rax,%rax
  4003c6:       74 02                   je     4003ca <_init+0x12>
  4003c8:       ff d0                   callq  *%rax
  4003ca:       48 83 c4 08             add    $0x8,%rsp
  4003ce:       c3                      retq   

Disassembly of section .text:

00000000004003d0 <_start>:
  4003d0:       31 ed                   xor    %ebp,%ebp
  4003d2:       49 89 d1                mov    %rdx,%r9
  4003d5:       5e                      pop    %rsi
  4003d6:       48 89 e2                mov    %rsp,%rdx
  4003d9:       48 83 e4 f0             and    $0xfffffffffffffff0,%rsp
  4003dd:       50                      push   %rax
  4003de:       54                      push   %rsp
  4003df:       49 c7 c0 a0 05 40 00    mov    $0x4005a0,%r8
  4003e6:       48 c7 c1 30 05 40 00    mov    $0x400530,%rcx
  4003ed:       48 c7 c7 ef 04 40 00    mov    $0x4004ef,%rdi
  4003f4:       ff 15 f6 0b 20 00       callq  *0x200bf6(%rip)        # 600ff0 <__libc_start_main@GLIBC_2.2.5>
  4003fa:       f4                      hlt    
  4003fb:       0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000400400 <_dl_relocate_static_pie>:
  400400:       f3 c3                   repz retq 
  400402:       66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  400409:       00 00 00 
  40040c:       0f 1f 40 00             nopl   0x0(%rax)

0000000000400410 <deregister_tm_clones>:
  400410:       b8 37 10 60 00          mov    $0x601037,%eax
  400415:       55                      push   %rbp
  400416:       48 2d 30 10 60 00       sub    $0x601030,%rax
  40041c:       48 83 f8 0e             cmp    $0xe,%rax
  400420:       48 89 e5                mov    %rsp,%rbp
  400423:       76 1b                   jbe    400440 <deregister_tm_clones+0x30>
  400425:       b8 00 00 00 00          mov    $0x0,%eax
  40042a:       48 85 c0                test   %rax,%rax
  40042d:       74 11                   je     400440 <deregister_tm_clones+0x30>
  40042f:       5d                      pop    %rbp
  400430:       bf 30 10 60 00          mov    $0x601030,%edi
  400435:       ff e0                   jmpq   *%rax
  400437:       66 0f 1f 84 00 00 00    nopw   0x0(%rax,%rax,1)
  40043e:       00 00 
  400440:       5d                      pop    %rbp
  400441:       c3                      retq   
  400442:       0f 1f 40 00             nopl   0x0(%rax)
  400446:       66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  40044d:       00 00 00 

0000000000400450 <register_tm_clones>:
  400450:       be 30 10 60 00          mov    $0x601030,%esi
  400455:       55                      push   %rbp
  400456:       48 81 ee 30 10 60 00    sub    $0x601030,%rsi
  40045d:       48 c1 fe 03             sar    $0x3,%rsi
  400461:       48 89 e5                mov    %rsp,%rbp
  400464:       48 89 f0                mov    %rsi,%rax
  400467:       48 c1 e8 3f             shr    $0x3f,%rax
  40046b:       48 01 c6                add    %rax,%rsi
  40046e:       48 d1 fe                sar    %rsi
  400471:       74 15                   je     400488 <register_tm_clones+0x38>
  400473:       b8 00 00 00 00          mov    $0x0,%eax
  400478:       48 85 c0                test   %rax,%rax
  40047b:       74 0b                   je     400488 <register_tm_clones+0x38>
  40047d:       5d                      pop    %rbp
  40047e:       bf 30 10 60 00          mov    $0x601030,%edi
  400483:       ff e0                   jmpq   *%rax
  400485:       0f 1f 00                nopl   (%rax)
  400488:       5d                      pop    %rbp
  400489:       c3                      retq   
  40048a:       66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)

0000000000400490 <__do_global_dtors_aux>:
  400490:       80 3d 95 0b 20 00 00    cmpb   $0x0,0x200b95(%rip)        # 60102c <_edata>
  400497:       75 11                   jne    4004aa <__do_global_dtors_aux+0x1a>
  400499:       55                      push   %rbp
  40049a:       48 89 e5                mov    %rsp,%rbp
  40049d:       e8 6e ff ff ff          callq  400410 <deregister_tm_clones>
  4004a2:       5d                      pop    %rbp
  4004a3:       c6 05 82 0b 20 00 01    movb   $0x1,0x200b82(%rip)        # 60102c <_edata>
  4004aa:       f3 c3                   repz retq 
  4004ac:       0f 1f 40 00             nopl   0x0(%rax)

00000000004004b0 <frame_dummy>:
  4004b0:       bf 28 0e 60 00          mov    $0x600e28,%edi
  4004b5:       48 83 3f 00             cmpq   $0x0,(%rdi)
  4004b9:       75 05                   jne    4004c0 <frame_dummy+0x10>
  4004bb:       eb 93                   jmp    400450 <register_tm_clones>
  4004bd:       0f 1f 00                nopl   (%rax)
  4004c0:       b8 00 00 00 00          mov    $0x0,%eax
  4004c5:       48 85 c0                test   %rax,%rax
  4004c8:       74 f1                   je     4004bb <frame_dummy+0xb>
  4004ca:       55                      push   %rbp
  4004cb:       48 89 e5                mov    %rsp,%rbp
  4004ce:       ff d0                   callq  *%rax
  4004d0:       5d                      pop    %rbp
  4004d1:       e9 7a ff ff ff          jmpq   400450 <register_tm_clones>

00000000004004d6 <_Z9main_funcii>:
  4004d6:       55                      push   %rbp
  4004d7:       48 89 e5                mov    %rsp,%rbp
  4004da:       89 7d fc                mov    %edi,-0x4(%rbp)
  4004dd:       89 75 f8                mov    %esi,-0x8(%rbp)
  4004e0:       8b 55 fc                mov    -0x4(%rbp),%edx
  4004e3:       8b 45 f8                mov    -0x8(%rbp),%eax
  4004e6:       01 d0                   add    %edx,%eax
  4004e8:       05 c3 07 00 00          add    $0x7c3,%eax
  4004ed:       5d                      pop    %rbp
  4004ee:       c3                      retq   

00000000004004ef <main>:
  4004ef:       55                      push   %rbp
  4004f0:       48 89 e5                mov    %rsp,%rbp
  4004f3:       48 83 ec 20             sub    $0x20,%rsp
  4004f7:       89 7d ec                mov    %edi,-0x14(%rbp)
  4004fa:       48 89 75 e0             mov    %rsi,-0x20(%rbp)
  4004fe:       c7 45 fc 00 00 00 00    movl   $0x0,-0x4(%rbp)
  400505:       8b 45 ec                mov    -0x14(%rbp),%eax
  400508:       89 05 22 0b 20 00       mov    %eax,0x200b22(%rip)        # 601030 <__TMC_END__>
  40050e:       8b 15 14 0b 20 00       mov    0x200b14(%rip),%edx        # 601028 <g_static_data>
  400514:       8b 05 16 0b 20 00       mov    0x200b16(%rip),%eax        # 601030 <__TMC_END__>
  40051a:       89 d6                   mov    %edx,%esi
  40051c:       89 c7                   mov    %eax,%edi
  40051e:       e8 b3 ff ff ff          callq  4004d6 <_Z9main_funcii>
  400523:       01 45 fc                add    %eax,-0x4(%rbp)
  400526:       8b 45 fc                mov    -0x4(%rbp),%eax
  400529:       c9                      leaveq 
  40052a:       c3                      retq   
  40052b:       0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000400530 <__libc_csu_init>:
  400530:       41 57                   push   %r15
  400532:       41 56                   push   %r14
  400534:       49 89 d7                mov    %rdx,%r15
  400537:       41 55                   push   %r13
  400539:       41 54                   push   %r12
  40053b:       4c 8d 25 d6 08 20 00    lea    0x2008d6(%rip),%r12        # 600e18 <__frame_dummy_init_array_entry>
  400542:       55                      push   %rbp
  400543:       48 8d 2d d6 08 20 00    lea    0x2008d6(%rip),%rbp        # 600e20 <__init_array_end>
  40054a:       53                      push   %rbx
  40054b:       41 89 fd                mov    %edi,%r13d
  40054e:       49 89 f6                mov    %rsi,%r14
  400551:       4c 29 e5                sub    %r12,%rbp
  400554:       48 83 ec 08             sub    $0x8,%rsp
  400558:       48 c1 fd 03             sar    $0x3,%rbp
  40055c:       e8 57 fe ff ff          callq  4003b8 <_init>
  400561:       48 85 ed                test   %rbp,%rbp
  400564:       74 20                   je     400586 <__libc_csu_init+0x56>
  400566:       31 db                   xor    %ebx,%ebx
  400568:       0f 1f 84 00 00 00 00    nopl   0x0(%rax,%rax,1)
  40056f:       00 
  400570:       4c 89 fa                mov    %r15,%rdx
  400573:       4c 89 f6                mov    %r14,%rsi
  400576:       44 89 ef                mov    %r13d,%edi
  400579:       41 ff 14 dc             callq  *(%r12,%rbx,8)
  40057d:       48 83 c3 01             add    $0x1,%rbx
  400581:       48 39 dd                cmp    %rbx,%rbp
  400584:       75 ea                   jne    400570 <__libc_csu_init+0x40>
  400586:       48 83 c4 08             add    $0x8,%rsp
  40058a:       5b                      pop    %rbx
  40058b:       5d                      pop    %rbp
  40058c:       41 5c                   pop    %r12
  40058e:       41 5d                   pop    %r13
  400590:       41 5e                   pop    %r14
  400592:       41 5f                   pop    %r15
  400594:       c3                      retq   
  400595:       90                      nop
  400596:       66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  40059d:       00 00 00 

00000000004005a0 <__libc_csu_fini>:
  4005a0:       f3 c3                   repz retq 

Disassembly of section .fini:

00000000004005a4 <_fini>:
  4005a4:       48 83 ec 08             sub    $0x8,%rsp
  4005a8:       48 83 c4 08             add    $0x8,%rsp
  4005ac:       c3                      retq  
```

##### 可执行文件 (相对位置的PIE(DYN)版本)
``` ARMASM

重定位节 '.rela.dyn' 位于偏移量 0x448 含有 9 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000200dd8  000000000008 R_X86_64_RELATIVE                    660
000000200de0  000000000008 R_X86_64_RELATIVE                    620
000000201020  000000000008 R_X86_64_RELATIVE                    201020
000000200fd0  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __cxa_finalize@GLIBC_2.2.5 + 0
000000200fd8  000200000006 R_X86_64_GLOB_DAT 0000000000000000 _Jv_RegisterClasses + 0
000000200fe0  000300000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_deregisterTMClone + 0
000000200fe8  000400000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.2.5 + 0
000000200ff0  000500000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0
000000200ff8  000600000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_registerTMCloneTa + 0

The decoding of unwind sections for machine type Advanced Micro Devices X86-64 is not currently supported.

Symbol table '.dynsym' contains 7 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FUNC    WEAK   DEFAULT  UND __cxa_finalize@GLIBC_2.2.5 (2)
     2: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _Jv_RegisterClasses
     3: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_deregisterTMCloneTab
     4: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@GLIBC_2.2.5 (2)
     5: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
     6: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_registerTMCloneTable

Symbol table '.symtab' contains 70 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000238     0 SECTION LOCAL  DEFAULT    1 
     2: 0000000000000254     0 SECTION LOCAL  DEFAULT    2 
     3: 0000000000000274     0 SECTION LOCAL  DEFAULT    3 
     4: 0000000000000298     0 SECTION LOCAL  DEFAULT    4 
     5: 00000000000002b8     0 SECTION LOCAL  DEFAULT    5 
     6: 0000000000000360     0 SECTION LOCAL  DEFAULT    6 
     7: 0000000000000418     0 SECTION LOCAL  DEFAULT    7 
     8: 0000000000000428     0 SECTION LOCAL  DEFAULT    8 
     9: 0000000000000448     0 SECTION LOCAL  DEFAULT    9 
    10: 0000000000000520     0 SECTION LOCAL  DEFAULT   10 
    11: 0000000000000540     0 SECTION LOCAL  DEFAULT   11 
    12: 0000000000000550     0 SECTION LOCAL  DEFAULT   12 
    13: 0000000000000560     0 SECTION LOCAL  DEFAULT   13 
    14: 0000000000000764     0 SECTION LOCAL  DEFAULT   14 
    15: 0000000000000770     0 SECTION LOCAL  DEFAULT   15 
    16: 0000000000000778     0 SECTION LOCAL  DEFAULT   16 
    17: 00000000000007c0     0 SECTION LOCAL  DEFAULT   17 
    18: 0000000000200dd8     0 SECTION LOCAL  DEFAULT   18 
    19: 0000000000200de0     0 SECTION LOCAL  DEFAULT   19 
    20: 0000000000200de8     0 SECTION LOCAL  DEFAULT   20 
    21: 0000000000200df0     0 SECTION LOCAL  DEFAULT   21 
    22: 0000000000200fd0     0 SECTION LOCAL  DEFAULT   22 
    23: 0000000000201000     0 SECTION LOCAL  DEFAULT   23 
    24: 0000000000201018     0 SECTION LOCAL  DEFAULT   24 
    25: 000000000020102c     0 SECTION LOCAL  DEFAULT   25 
    26: 0000000000000000     0 SECTION LOCAL  DEFAULT   26 
    27: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    28: 0000000000200de8     0 OBJECT  LOCAL  DEFAULT   20 __JCR_LIST__
    29: 0000000000000590     0 FUNC    LOCAL  DEFAULT   13 deregister_tm_clones
    30: 00000000000005d0     0 FUNC    LOCAL  DEFAULT   13 register_tm_clones
    31: 0000000000000620     0 FUNC    LOCAL  DEFAULT   13 __do_global_dtors_aux
    32: 000000000020102c     1 OBJECT  LOCAL  DEFAULT   25 completed.6972
    33: 0000000000200de0     0 OBJECT  LOCAL  DEFAULT   19 __do_global_dtors_aux_fin
    34: 0000000000000660     0 FUNC    LOCAL  DEFAULT   13 frame_dummy
    35: 0000000000200dd8     0 OBJECT  LOCAL  DEFAULT   18 __frame_dummy_init_array_
    36: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS test.cpp
    37: 0000000000000774     4 OBJECT  LOCAL  DEFAULT   15 _ZL13g_static_text
    38: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    39: 00000000000008e8     0 OBJECT  LOCAL  DEFAULT   17 __FRAME_END__
    40: 0000000000200de8     0 OBJECT  LOCAL  DEFAULT   20 __JCR_END__
    41: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS 
    42: 0000000000000778     0 NOTYPE  LOCAL  DEFAULT   16 __GNU_EH_FRAME_HDR
    43: 0000000000200df0     0 OBJECT  LOCAL  DEFAULT   21 _DYNAMIC
    44: 0000000000200de0     0 NOTYPE  LOCAL  DEFAULT   18 __init_array_end
    45: 0000000000200dd8     0 NOTYPE  LOCAL  DEFAULT   18 __init_array_start
    46: 0000000000201000     0 OBJECT  LOCAL  DEFAULT   23 _GLOBAL_OFFSET_TABLE_
    47: 0000000000201028     4 OBJECT  GLOBAL DEFAULT   24 g_static_data
    48: 000000000020102c     0 NOTYPE  GLOBAL DEFAULT   24 _edata
    49: 0000000000201018     0 NOTYPE  WEAK   DEFAULT   24 data_start
    50: 0000000000000770     4 OBJECT  GLOBAL DEFAULT   15 _IO_stdin_used
    51: 0000000000000690    25 FUNC    GLOBAL DEFAULT   13 _Z9main_funcii
    52: 0000000000000000     0 FUNC    WEAK   DEFAULT  UND __cxa_finalize@@GLIBC_2.2
    53: 00000000000006a9    60 FUNC    GLOBAL DEFAULT   13 main
    54: 0000000000201020     0 OBJECT  GLOBAL HIDDEN    24 __dso_handle
    55: 0000000000000764     0 FUNC    GLOBAL DEFAULT   14 _fini
    56: 0000000000000560    43 FUNC    GLOBAL DEFAULT   13 _start
    57: 0000000000000520     0 FUNC    GLOBAL DEFAULT   10 _init
    58: 0000000000201030     0 OBJECT  GLOBAL HIDDEN    24 __TMC_END__
    59: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _Jv_RegisterClasses
    60: 0000000000201018     0 NOTYPE  GLOBAL DEFAULT   24 __data_start
    61: 0000000000201038     0 NOTYPE  GLOBAL DEFAULT   25 _end
    62: 000000000020102c     0 NOTYPE  GLOBAL DEFAULT   25 __bss_start
    63: 00000000000006f0   101 FUNC    GLOBAL DEFAULT   13 __libc_csu_init
    64: 0000000000201030     4 OBJECT  GLOBAL DEFAULT   25 g_static_bss
    65: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_deregisterTMCloneTab
    66: 0000000000000760     2 FUNC    GLOBAL DEFAULT   13 __libc_csu_fini
    67: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@@GLIBC_
    68: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
    69: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_registerTMCloneTable

.text
0000000000000520 <_init>:
 520:   48 83 ec 08             sub    $0x8,%rsp
 524:   48 8b 05 c5 0a 20 00    mov    0x200ac5(%rip),%rax        # 200ff0 <__gmon_start__>
 52b:   48 85 c0                test   %rax,%rax
 52e:   74 02                   je     532 <_init+0x12>
 530:   ff d0                   callq  *%rax
 532:   48 83 c4 08             add    $0x8,%rsp
 536:   c3                      retq   

Disassembly of section .plt:

0000000000000540 <.plt>:
 540:   ff 35 c2 0a 20 00       pushq  0x200ac2(%rip)        # 201008 <_GLOBAL_OFFSET_TABLE_+0x8>
 546:   ff 25 c4 0a 20 00       jmpq   *0x200ac4(%rip)        # 201010 <_GLOBAL_OFFSET_TABLE_+0x10>
 54c:   0f 1f 40 00             nopl   0x0(%rax)

Disassembly of section .plt.got:

0000000000000550 <.plt.got>:
 550:   ff 25 7a 0a 20 00       jmpq   *0x200a7a(%rip)        # 200fd0 <__cxa_finalize@GLIBC_2.2.5>
 556:   66 90                   xchg   %ax,%ax

Disassembly of section .text:

0000000000000560 <_start>:
 560:   31 ed                   xor    %ebp,%ebp
 562:   49 89 d1                mov    %rdx,%r9
 565:   5e                      pop    %rsi
 566:   48 89 e2                mov    %rsp,%rdx
 569:   48 83 e4 f0             and    $0xfffffffffffffff0,%rsp
 56d:   50                      push   %rax
 56e:   54                      push   %rsp
 56f:   4c 8d 05 ea 01 00 00    lea    0x1ea(%rip),%r8        # 760 <__libc_csu_fini>
 576:   48 8d 0d 73 01 00 00    lea    0x173(%rip),%rcx        # 6f0 <__libc_csu_init>
 57d:   48 8d 3d 25 01 00 00    lea    0x125(%rip),%rdi        # 6a9 <main>
 584:   ff 15 5e 0a 20 00       callq  *0x200a5e(%rip)        # 200fe8 <__libc_start_main@GLIBC_2.2.5>
 58a:   f4                      hlt    
 58b:   0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000000590 <deregister_tm_clones>:
 590:   48 8d 3d 99 0a 20 00    lea    0x200a99(%rip),%rdi        # 201030 <__TMC_END__>
 597:   48 8d 05 99 0a 20 00    lea    0x200a99(%rip),%rax        # 201037 <__TMC_END__+0x7>
 59e:   55                      push   %rbp
 59f:   48 29 f8                sub    %rdi,%rax
 5a2:   48 89 e5                mov    %rsp,%rbp
 5a5:   48 83 f8 0e             cmp    $0xe,%rax
 5a9:   76 15                   jbe    5c0 <deregister_tm_clones+0x30>
 5ab:   48 8b 05 2e 0a 20 00    mov    0x200a2e(%rip),%rax        # 200fe0 <_ITM_deregisterTMCloneTable>
 5b2:   48 85 c0                test   %rax,%rax
 5b5:   74 09                   je     5c0 <deregister_tm_clones+0x30>
 5b7:   5d                      pop    %rbp
 5b8:   ff e0                   jmpq   *%rax
 5ba:   66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)
 5c0:   5d                      pop    %rbp
 5c1:   c3                      retq   
 5c2:   0f 1f 40 00             nopl   0x0(%rax)
 5c6:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 5cd:   00 00 00 

00000000000005d0 <register_tm_clones>:
 5d0:   48 8d 3d 59 0a 20 00    lea    0x200a59(%rip),%rdi        # 201030 <__TMC_END__>
 5d7:   48 8d 35 52 0a 20 00    lea    0x200a52(%rip),%rsi        # 201030 <__TMC_END__>
 5de:   55                      push   %rbp
 5df:   48 29 fe                sub    %rdi,%rsi
 5e2:   48 89 e5                mov    %rsp,%rbp
 5e5:   48 c1 fe 03             sar    $0x3,%rsi
 5e9:   48 89 f0                mov    %rsi,%rax
 5ec:   48 c1 e8 3f             shr    $0x3f,%rax
 5f0:   48 01 c6                add    %rax,%rsi
 5f3:   48 d1 fe                sar    %rsi
 5f6:   74 18                   je     610 <register_tm_clones+0x40>
 5f8:   48 8b 05 f9 09 20 00    mov    0x2009f9(%rip),%rax        # 200ff8 <_ITM_registerTMCloneTable>
 5ff:   48 85 c0                test   %rax,%rax
 602:   74 0c                   je     610 <register_tm_clones+0x40>
 604:   5d                      pop    %rbp
 605:   ff e0                   jmpq   *%rax
 607:   66 0f 1f 84 00 00 00    nopw   0x0(%rax,%rax,1)
 60e:   00 00 
 610:   5d                      pop    %rbp
 611:   c3                      retq   
 612:   0f 1f 40 00             nopl   0x0(%rax)
 616:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 61d:   00 00 00 

0000000000000620 <__do_global_dtors_aux>:
 620:   80 3d 05 0a 20 00 00    cmpb   $0x0,0x200a05(%rip)        # 20102c <_edata>
 627:   75 27                   jne    650 <__do_global_dtors_aux+0x30>
 629:   48 83 3d 9f 09 20 00    cmpq   $0x0,0x20099f(%rip)        # 200fd0 <__cxa_finalize@GLIBC_2.2.5>
 630:   00 
 631:   55                      push   %rbp
 632:   48 89 e5                mov    %rsp,%rbp
 635:   74 0c                   je     643 <__do_global_dtors_aux+0x23>
 637:   48 8b 3d e2 09 20 00    mov    0x2009e2(%rip),%rdi        # 201020 <__dso_handle>
 63e:   e8 0d ff ff ff          callq  550 <.plt.got>
 643:   e8 48 ff ff ff          callq  590 <deregister_tm_clones>
 648:   5d                      pop    %rbp
 649:   c6 05 dc 09 20 00 01    movb   $0x1,0x2009dc(%rip)        # 20102c <_edata>
 650:   f3 c3                   repz retq 
 652:   0f 1f 40 00             nopl   0x0(%rax)
 656:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 65d:   00 00 00 

0000000000000660 <frame_dummy>:
 660:   48 8d 3d 81 07 20 00    lea    0x200781(%rip),%rdi        # 200de8 <__JCR_END__>
 667:   48 83 3f 00             cmpq   $0x0,(%rdi)
 66b:   75 0b                   jne    678 <frame_dummy+0x18>
 66d:   e9 5e ff ff ff          jmpq   5d0 <register_tm_clones>
 672:   66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)
 678:   48 8b 05 59 09 20 00    mov    0x200959(%rip),%rax        # 200fd8 <_Jv_RegisterClasses>
 67f:   48 85 c0                test   %rax,%rax
 682:   74 e9                   je     66d <frame_dummy+0xd>
 684:   55                      push   %rbp
 685:   48 89 e5                mov    %rsp,%rbp
 688:   ff d0                   callq  *%rax
 68a:   5d                      pop    %rbp
 68b:   e9 40 ff ff ff          jmpq   5d0 <register_tm_clones>

0000000000000690 <_Z9main_funcii>:
 690:   55                      push   %rbp
 691:   48 89 e5                mov    %rsp,%rbp
 694:   89 7d fc                mov    %edi,-0x4(%rbp)
 697:   89 75 f8                mov    %esi,-0x8(%rbp)
 69a:   8b 55 fc                mov    -0x4(%rbp),%edx
 69d:   8b 45 f8                mov    -0x8(%rbp),%eax
 6a0:   01 d0                   add    %edx,%eax
 6a2:   05 c3 07 00 00          add    $0x7c3,%eax
 6a7:   5d                      pop    %rbp
 6a8:   c3                      retq   

00000000000006a9 <main>:
 6a9:   55                      push   %rbp
 6aa:   48 89 e5                mov    %rsp,%rbp
 6ad:   48 83 ec 20             sub    $0x20,%rsp
 6b1:   89 7d ec                mov    %edi,-0x14(%rbp)
 6b4:   48 89 75 e0             mov    %rsi,-0x20(%rbp)
 6b8:   c7 45 fc 00 00 00 00    movl   $0x0,-0x4(%rbp)
 6bf:   8b 45 ec                mov    -0x14(%rbp),%eax
 6c2:   89 05 68 09 20 00       mov    %eax,0x200968(%rip)        # 201030 <__TMC_END__>
 6c8:   8b 15 5a 09 20 00       mov    0x20095a(%rip),%edx        # 201028 <g_static_data>
 6ce:   8b 05 5c 09 20 00       mov    0x20095c(%rip),%eax        # 201030 <__TMC_END__>
 6d4:   89 d6                   mov    %edx,%esi
 6d6:   89 c7                   mov    %eax,%edi
 6d8:   e8 b3 ff ff ff          callq  690 <_Z9main_funcii>
 6dd:   01 45 fc                add    %eax,-0x4(%rbp)
 6e0:   8b 45 fc                mov    -0x4(%rbp),%eax
 6e3:   c9                      leaveq 
 6e4:   c3                      retq   
 6e5:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 6ec:   00 00 00 
 6ef:   90                      nop

00000000000006f0 <__libc_csu_init>:
 6f0:   41 57                   push   %r15
 6f2:   41 56                   push   %r14
 6f4:   49 89 d7                mov    %rdx,%r15
 6f7:   41 55                   push   %r13
 6f9:   41 54                   push   %r12
 6fb:   4c 8d 25 d6 06 20 00    lea    0x2006d6(%rip),%r12        # 200dd8 <__frame_dummy_init_array_entry>
 702:   55                      push   %rbp
 703:   48 8d 2d d6 06 20 00    lea    0x2006d6(%rip),%rbp        # 200de0 <__init_array_end>
 70a:   53                      push   %rbx
 70b:   41 89 fd                mov    %edi,%r13d
 70e:   49 89 f6                mov    %rsi,%r14
 711:   4c 29 e5                sub    %r12,%rbp
 714:   48 83 ec 08             sub    $0x8,%rsp
 718:   48 c1 fd 03             sar    $0x3,%rbp
 71c:   e8 ff fd ff ff          callq  520 <_init>
 721:   48 85 ed                test   %rbp,%rbp
 724:   74 20                   je     746 <__libc_csu_init+0x56>
 726:   31 db                   xor    %ebx,%ebx
 728:   0f 1f 84 00 00 00 00    nopl   0x0(%rax,%rax,1)
 72f:   00 
 730:   4c 89 fa                mov    %r15,%rdx
 733:   4c 89 f6                mov    %r14,%rsi
 736:   44 89 ef                mov    %r13d,%edi
 739:   41 ff 14 dc             callq  *(%r12,%rbx,8)
 73d:   48 83 c3 01             add    $0x1,%rbx
 741:   48 39 dd                cmp    %rbx,%rbp
 744:   75 ea                   jne    730 <__libc_csu_init+0x40>
 746:   48 83 c4 08             add    $0x8,%rsp
 74a:   5b                      pop    %rbx
 74b:   5d                      pop    %rbp
 74c:   41 5c                   pop    %r12
 74e:   41 5d                   pop    %r13
 750:   41 5e                   pop    %r14
 752:   41 5f                   pop    %r15
 754:   c3                      retq   
 755:   90                      nop
 756:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 75d:   00 00 00 

0000000000000760 <__libc_csu_fini>:
 760:   f3 c3                   repz retq 

Disassembly of section .fini:

0000000000000764 <_fini>:
 764:   48 83 ec 08             sub    $0x8,%rsp
 768:   48 83 c4 08             add    $0x8,%rsp
 76c:   c3                      retq   
```


##### 可执行文件 (位置无关的非PIE(EXEC)版本)  

``` ARMASM
Dynamic section at offset 0xe30 contains 23 entries:
  标记        类型                         名称/值
 0x0000000000000001 (NEEDED)             共享库：[libstdc++.so.6]
 0x0000000000000001 (NEEDED)             共享库：[libm.so.6]
 0x0000000000000001 (NEEDED)             共享库：[libgcc_s.so.1]
 0x0000000000000001 (NEEDED)             共享库：[libc.so.6]
 0x000000000000000c (INIT)               0x4003b8
 0x000000000000000d (FINI)               0x4005b4
 0x0000000000000019 (INIT_ARRAY)         0x600e18
 0x000000000000001b (INIT_ARRAYSZ)       8 (bytes)
 0x000000000000001a (FINI_ARRAY)         0x600e20
 0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
 0x000000006ffffef5 (GNU_HASH)           0x400298
 0x0000000000000005 (STRTAB)             0x400300
 0x0000000000000006 (SYMTAB)             0x4002b8
 0x000000000000000a (STRSZ)              95 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000015 (DEBUG)              0x0
 0x0000000000000007 (RELA)               0x400388
 0x0000000000000008 (RELASZ)             48 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000006ffffffe (VERNEED)            0x400368
 0x000000006fffffff (VERNEEDNUM)         1
 0x000000006ffffff0 (VERSYM)             0x400360
 0x0000000000000000 (NULL)               0x0

重定位节 '.rela.dyn' 位于偏移量 0x388 含有 2 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000600ff0  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.2.5 + 0
000000600ff8  000200000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0

The decoding of unwind sections for machine type Advanced Micro Devices X86-64 is not currently supported.

Symbol table '.dynsym' contains 3 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@GLIBC_2.2.5 (2)
     2: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__

Symbol table '.symtab' contains 65 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000400238     0 SECTION LOCAL  DEFAULT    1 
     2: 0000000000400254     0 SECTION LOCAL  DEFAULT    2 
     3: 0000000000400274     0 SECTION LOCAL  DEFAULT    3 
     4: 0000000000400298     0 SECTION LOCAL  DEFAULT    4 
     5: 00000000004002b8     0 SECTION LOCAL  DEFAULT    5 
     6: 0000000000400300     0 SECTION LOCAL  DEFAULT    6 
     7: 0000000000400360     0 SECTION LOCAL  DEFAULT    7 
     8: 0000000000400368     0 SECTION LOCAL  DEFAULT    8 
     9: 0000000000400388     0 SECTION LOCAL  DEFAULT    9 
    10: 00000000004003b8     0 SECTION LOCAL  DEFAULT   10 
    11: 00000000004003d0     0 SECTION LOCAL  DEFAULT   11 
    12: 00000000004005b4     0 SECTION LOCAL  DEFAULT   12 
    13: 00000000004005c0     0 SECTION LOCAL  DEFAULT   13 
    14: 00000000004005c8     0 SECTION LOCAL  DEFAULT   14 
    15: 0000000000400608     0 SECTION LOCAL  DEFAULT   15 
    16: 0000000000600e18     0 SECTION LOCAL  DEFAULT   16 
    17: 0000000000600e20     0 SECTION LOCAL  DEFAULT   17 
    18: 0000000000600e28     0 SECTION LOCAL  DEFAULT   18 
    19: 0000000000600e30     0 SECTION LOCAL  DEFAULT   19 
    20: 0000000000600ff0     0 SECTION LOCAL  DEFAULT   20 
    21: 0000000000601000     0 SECTION LOCAL  DEFAULT   21 
    22: 0000000000601018     0 SECTION LOCAL  DEFAULT   22 
    23: 000000000060102c     0 SECTION LOCAL  DEFAULT   23 
    24: 0000000000000000     0 SECTION LOCAL  DEFAULT   24 
    25: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    26: 0000000000600e28     0 OBJECT  LOCAL  DEFAULT   18 __JCR_LIST__
    27: 0000000000400410     0 FUNC    LOCAL  DEFAULT   11 deregister_tm_clones
    28: 0000000000400450     0 FUNC    LOCAL  DEFAULT   11 register_tm_clones
    29: 0000000000400490     0 FUNC    LOCAL  DEFAULT   11 __do_global_dtors_aux
    30: 000000000060102c     1 OBJECT  LOCAL  DEFAULT   23 completed.6972
    31: 0000000000600e20     0 OBJECT  LOCAL  DEFAULT   17 __do_global_dtors_aux_fin
    32: 00000000004004b0     0 FUNC    LOCAL  DEFAULT   11 frame_dummy
    33: 0000000000600e18     0 OBJECT  LOCAL  DEFAULT   16 __frame_dummy_init_array_
    34: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS test.cpp
    35: 00000000004005c4     4 OBJECT  LOCAL  DEFAULT   13 _ZL13g_static_text
    36: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    37: 0000000000400708     0 OBJECT  LOCAL  DEFAULT   15 __FRAME_END__
    38: 0000000000600e28     0 OBJECT  LOCAL  DEFAULT   18 __JCR_END__
    39: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS 
    40: 00000000004005c8     0 NOTYPE  LOCAL  DEFAULT   14 __GNU_EH_FRAME_HDR
    41: 0000000000600e30     0 OBJECT  LOCAL  DEFAULT   19 _DYNAMIC
    42: 0000000000600e20     0 NOTYPE  LOCAL  DEFAULT   16 __init_array_end
    43: 0000000000600e18     0 NOTYPE  LOCAL  DEFAULT   16 __init_array_start
    44: 0000000000601000     0 OBJECT  LOCAL  DEFAULT   21 _GLOBAL_OFFSET_TABLE_
    45: 0000000000601028     4 OBJECT  GLOBAL DEFAULT   22 g_static_data
    46: 000000000060102c     0 NOTYPE  GLOBAL DEFAULT   22 _edata
    47: 0000000000601018     0 NOTYPE  WEAK   DEFAULT   22 data_start
    48: 00000000004005c0     4 OBJECT  GLOBAL DEFAULT   13 _IO_stdin_used
    49: 00000000004004d6    25 FUNC    GLOBAL DEFAULT   11 _Z9main_funcii
    50: 00000000004004ef    69 FUNC    GLOBAL DEFAULT   11 main
    51: 0000000000601020     0 OBJECT  GLOBAL HIDDEN    22 __dso_handle
    52: 00000000004005b4     0 FUNC    GLOBAL DEFAULT   12 _fini
    53: 0000000000400400     2 FUNC    GLOBAL HIDDEN    11 _dl_relocate_static_pie
    54: 00000000004003d0    43 FUNC    GLOBAL DEFAULT   11 _start
    55: 00000000004003b8     0 FUNC    GLOBAL DEFAULT   10 _init
    56: 0000000000601030     0 OBJECT  GLOBAL HIDDEN    22 __TMC_END__
    57: 0000000000601018     0 NOTYPE  GLOBAL DEFAULT   22 __data_start
    58: 0000000000601038     0 NOTYPE  GLOBAL DEFAULT   23 _end
    59: 000000000060102c     0 NOTYPE  GLOBAL DEFAULT   23 __bss_start
    60: 0000000000400540   101 FUNC    GLOBAL DEFAULT   11 __libc_csu_init
    61: 0000000000601030     4 OBJECT  GLOBAL DEFAULT   23 g_static_bss
    62: 00000000004005b0     2 FUNC    GLOBAL DEFAULT   11 __libc_csu_fini
    63: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@@GLIBC_
    64: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__


.text
00000000004003b8 <_init>:
  4003b8:       48 83 ec 08             sub    $0x8,%rsp
  4003bc:       48 8b 05 35 0c 20 00    mov    0x200c35(%rip),%rax        # 600ff8 <__gmon_start__>
  4003c3:       48 85 c0                test   %rax,%rax
  4003c6:       74 02                   je     4003ca <_init+0x12>
  4003c8:       ff d0                   callq  *%rax
  4003ca:       48 83 c4 08             add    $0x8,%rsp
  4003ce:       c3                      retq   

Disassembly of section .text:

00000000004003d0 <_start>:
  4003d0:       31 ed                   xor    %ebp,%ebp
  4003d2:       49 89 d1                mov    %rdx,%r9
  4003d5:       5e                      pop    %rsi
  4003d6:       48 89 e2                mov    %rsp,%rdx
  4003d9:       48 83 e4 f0             and    $0xfffffffffffffff0,%rsp
  4003dd:       50                      push   %rax
  4003de:       54                      push   %rsp
  4003df:       49 c7 c0 b0 05 40 00    mov    $0x4005b0,%r8
  4003e6:       48 c7 c1 40 05 40 00    mov    $0x400540,%rcx
  4003ed:       48 c7 c7 ef 04 40 00    mov    $0x4004ef,%rdi
  4003f4:       ff 15 f6 0b 20 00       callq  *0x200bf6(%rip)        # 600ff0 <__libc_start_main@GLIBC_2.2.5>
  4003fa:       f4                      hlt    
  4003fb:       0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000400400 <_dl_relocate_static_pie>:
  400400:       f3 c3                   repz retq 
  400402:       66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  400409:       00 00 00 
  40040c:       0f 1f 40 00             nopl   0x0(%rax)

0000000000400410 <deregister_tm_clones>:
  400410:       b8 37 10 60 00          mov    $0x601037,%eax
  400415:       55                      push   %rbp
  400416:       48 2d 30 10 60 00       sub    $0x601030,%rax
  40041c:       48 83 f8 0e             cmp    $0xe,%rax
  400420:       48 89 e5                mov    %rsp,%rbp
  400423:       76 1b                   jbe    400440 <deregister_tm_clones+0x30>
  400425:       b8 00 00 00 00          mov    $0x0,%eax
  40042a:       48 85 c0                test   %rax,%rax
  40042d:       74 11                   je     400440 <deregister_tm_clones+0x30>
  40042f:       5d                      pop    %rbp
  400430:       bf 30 10 60 00          mov    $0x601030,%edi
  400435:       ff e0                   jmpq   *%rax
  400437:       66 0f 1f 84 00 00 00    nopw   0x0(%rax,%rax,1)
  40043e:       00 00 
  400440:       5d                      pop    %rbp
  400441:       c3                      retq   
  400442:       0f 1f 40 00             nopl   0x0(%rax)
  400446:       66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  40044d:       00 00 00 

0000000000400450 <register_tm_clones>:
  400450:       be 30 10 60 00          mov    $0x601030,%esi
  400455:       55                      push   %rbp
  400456:       48 81 ee 30 10 60 00    sub    $0x601030,%rsi
  40045d:       48 c1 fe 03             sar    $0x3,%rsi
  400461:       48 89 e5                mov    %rsp,%rbp
  400464:       48 89 f0                mov    %rsi,%rax
  400467:       48 c1 e8 3f             shr    $0x3f,%rax
  40046b:       48 01 c6                add    %rax,%rsi
  40046e:       48 d1 fe                sar    %rsi
  400471:       74 15                   je     400488 <register_tm_clones+0x38>
  400473:       b8 00 00 00 00          mov    $0x0,%eax
  400478:       48 85 c0                test   %rax,%rax
  40047b:       74 0b                   je     400488 <register_tm_clones+0x38>
  40047d:       5d                      pop    %rbp
  40047e:       bf 30 10 60 00          mov    $0x601030,%edi
  400483:       ff e0                   jmpq   *%rax
  400485:       0f 1f 00                nopl   (%rax)
  400488:       5d                      pop    %rbp
  400489:       c3                      retq   
  40048a:       66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)

0000000000400490 <__do_global_dtors_aux>:
  400490:       80 3d 95 0b 20 00 00    cmpb   $0x0,0x200b95(%rip)        # 60102c <_edata>
  400497:       75 11                   jne    4004aa <__do_global_dtors_aux+0x1a>
  400499:       55                      push   %rbp
  40049a:       48 89 e5                mov    %rsp,%rbp
  40049d:       e8 6e ff ff ff          callq  400410 <deregister_tm_clones>
  4004a2:       5d                      pop    %rbp
  4004a3:       c6 05 82 0b 20 00 01    movb   $0x1,0x200b82(%rip)        # 60102c <_edata>
  4004aa:       f3 c3                   repz retq 
  4004ac:       0f 1f 40 00             nopl   0x0(%rax)

00000000004004b0 <frame_dummy>:
  4004b0:       bf 28 0e 60 00          mov    $0x600e28,%edi
  4004b5:       48 83 3f 00             cmpq   $0x0,(%rdi)
  4004b9:       75 05                   jne    4004c0 <frame_dummy+0x10>
  4004bb:       eb 93                   jmp    400450 <register_tm_clones>
  4004bd:       0f 1f 00                nopl   (%rax)
  4004c0:       b8 00 00 00 00          mov    $0x0,%eax
  4004c5:       48 85 c0                test   %rax,%rax
  4004c8:       74 f1                   je     4004bb <frame_dummy+0xb>
  4004ca:       55                      push   %rbp
  4004cb:       48 89 e5                mov    %rsp,%rbp
  4004ce:       ff d0                   callq  *%rax
  4004d0:       5d                      pop    %rbp
  4004d1:       e9 7a ff ff ff          jmpq   400450 <register_tm_clones>

00000000004004d6 <_Z9main_funcii>:
  4004d6:       55                      push   %rbp
  4004d7:       48 89 e5                mov    %rsp,%rbp
  4004da:       89 7d fc                mov    %edi,-0x4(%rbp)
  4004dd:       89 75 f8                mov    %esi,-0x8(%rbp)
  4004e0:       8b 55 fc                mov    -0x4(%rbp),%edx
  4004e3:       8b 45 f8                mov    -0x8(%rbp),%eax
  4004e6:       01 d0                   add    %edx,%eax
  4004e8:       05 c3 07 00 00          add    $0x7c3,%eax
  4004ed:       5d                      pop    %rbp
  4004ee:       c3                      retq   

00000000004004ef <main>:
  4004ef:       55                      push   %rbp
  4004f0:       48 89 e5                mov    %rsp,%rbp
  4004f3:       48 83 ec 20             sub    $0x20,%rsp
  4004f7:       89 7d ec                mov    %edi,-0x14(%rbp)
  4004fa:       48 89 75 e0             mov    %rsi,-0x20(%rbp)
  4004fe:       c7 45 fc 00 00 00 00    movl   $0x0,-0x4(%rbp)
  400505:       48 c7 c0 30 10 60 00    mov    $0x601030,%rax
  40050c:       8b 55 ec                mov    -0x14(%rbp),%edx
  40050f:       89 10                   mov    %edx,(%rax)
  400511:       48 c7 c0 28 10 60 00    mov    $0x601028,%rax
  400518:       8b 10                   mov    (%rax),%edx
  40051a:       48 c7 c0 30 10 60 00    mov    $0x601030,%rax
  400521:       8b 00                   mov    (%rax),%eax
  400523:       89 d6                   mov    %edx,%esi
  400525:       89 c7                   mov    %eax,%edi
  400527:       e8 aa ff ff ff          callq  4004d6 <_Z9main_funcii>
  40052c:       01 45 fc                add    %eax,-0x4(%rbp)
  40052f:       8b 45 fc                mov    -0x4(%rbp),%eax
  400532:       c9                      leaveq 
  400533:       c3                      retq   
  400534:       66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  40053b:       00 00 00 
  40053e:       66 90                   xchg   %ax,%ax

0000000000400540 <__libc_csu_init>:
  400540:       41 57                   push   %r15
  400542:       41 56                   push   %r14
  400544:       49 89 d7                mov    %rdx,%r15
  400547:       41 55                   push   %r13
  400549:       41 54                   push   %r12
  40054b:       4c 8d 25 c6 08 20 00    lea    0x2008c6(%rip),%r12        # 600e18 <__frame_dummy_init_array_entry>
  400552:       55                      push   %rbp
  400553:       48 8d 2d c6 08 20 00    lea    0x2008c6(%rip),%rbp        # 600e20 <__init_array_end>
  40055a:       53                      push   %rbx
  40055b:       41 89 fd                mov    %edi,%r13d
  40055e:       49 89 f6                mov    %rsi,%r14
  400561:       4c 29 e5                sub    %r12,%rbp
  400564:       48 83 ec 08             sub    $0x8,%rsp
  400568:       48 c1 fd 03             sar    $0x3,%rbp
  40056c:       e8 47 fe ff ff          callq  4003b8 <_init>
  400571:       48 85 ed                test   %rbp,%rbp
  400574:       74 20                   je     400596 <__libc_csu_init+0x56>
  400576:       31 db                   xor    %ebx,%ebx
  400578:       0f 1f 84 00 00 00 00    nopl   0x0(%rax,%rax,1)
  40057f:       00 
  400580:       4c 89 fa                mov    %r15,%rdx
  400583:       4c 89 f6                mov    %r14,%rsi
  400586:       44 89 ef                mov    %r13d,%edi
  400589:       41 ff 14 dc             callq  *(%r12,%rbx,8)
  40058d:       48 83 c3 01             add    $0x1,%rbx
  400591:       48 39 dd                cmp    %rbx,%rbp
  400594:       75 ea                   jne    400580 <__libc_csu_init+0x40>
  400596:       48 83 c4 08             add    $0x8,%rsp
  40059a:       5b                      pop    %rbx
  40059b:       5d                      pop    %rbp
  40059c:       41 5c                   pop    %r12
  40059e:       41 5d                   pop    %r13
  4005a0:       41 5e                   pop    %r14
  4005a2:       41 5f                   pop    %r15
  4005a4:       c3                      retq   
  4005a5:       90                      nop
  4005a6:       66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  4005ad:       00 00 00 

00000000004005b0 <__libc_csu_fini>:
  4005b0:       f3 c3                   repz retq 

Disassembly of section .fini:

00000000004005b4 <_fini>:
  4005b4:       48 83 ec 08             sub    $0x8,%rsp
  4005b8:       48 83 c4 08             add    $0x8,%rsp
  4005bc:       c3                      retq  
```


##### 可执行文件 (位置无关的PIE(DYN)版本)  
```ARMASM
重定位节 '.rela.dyn' 位于偏移量 0x448 含有 9 个条目：
  偏移量          信息           类型           符号值        符号名称 + 加数
000000200dd8  000000000008 R_X86_64_RELATIVE                    660
000000200de0  000000000008 R_X86_64_RELATIVE                    620
000000201020  000000000008 R_X86_64_RELATIVE                    201020
000000200fd0  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __cxa_finalize@GLIBC_2.2.5 + 0
000000200fd8  000200000006 R_X86_64_GLOB_DAT 0000000000000000 _Jv_RegisterClasses + 0
000000200fe0  000300000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_deregisterTMClone + 0
000000200fe8  000400000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.2.5 + 0
000000200ff0  000500000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0
000000200ff8  000600000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_registerTMCloneTa + 0

The decoding of unwind sections for machine type Advanced Micro Devices X86-64 is not currently supported.

Symbol table '.dynsym' contains 7 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000000     0 FUNC    WEAK   DEFAULT  UND __cxa_finalize@GLIBC_2.2.5 (2)
     2: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _Jv_RegisterClasses
     3: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_deregisterTMCloneTab
     4: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@GLIBC_2.2.5 (2)
     5: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
     6: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_registerTMCloneTable

Symbol table '.symtab' contains 70 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     0: 0000000000000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 0000000000000238     0 SECTION LOCAL  DEFAULT    1 
     2: 0000000000000254     0 SECTION LOCAL  DEFAULT    2 
     3: 0000000000000274     0 SECTION LOCAL  DEFAULT    3 
     4: 0000000000000298     0 SECTION LOCAL  DEFAULT    4 
     5: 00000000000002b8     0 SECTION LOCAL  DEFAULT    5 
     6: 0000000000000360     0 SECTION LOCAL  DEFAULT    6 
     7: 0000000000000418     0 SECTION LOCAL  DEFAULT    7 
     8: 0000000000000428     0 SECTION LOCAL  DEFAULT    8 
     9: 0000000000000448     0 SECTION LOCAL  DEFAULT    9 
    10: 0000000000000520     0 SECTION LOCAL  DEFAULT   10 
    11: 0000000000000540     0 SECTION LOCAL  DEFAULT   11 
    12: 0000000000000550     0 SECTION LOCAL  DEFAULT   12 
    13: 0000000000000560     0 SECTION LOCAL  DEFAULT   13 
    14: 0000000000000764     0 SECTION LOCAL  DEFAULT   14 
    15: 0000000000000770     0 SECTION LOCAL  DEFAULT   15 
    16: 0000000000000778     0 SECTION LOCAL  DEFAULT   16 
    17: 00000000000007c0     0 SECTION LOCAL  DEFAULT   17 
    18: 0000000000200dd8     0 SECTION LOCAL  DEFAULT   18 
    19: 0000000000200de0     0 SECTION LOCAL  DEFAULT   19 
    20: 0000000000200de8     0 SECTION LOCAL  DEFAULT   20 
    21: 0000000000200df0     0 SECTION LOCAL  DEFAULT   21 
    22: 0000000000200fd0     0 SECTION LOCAL  DEFAULT   22 
    23: 0000000000201000     0 SECTION LOCAL  DEFAULT   23 
    24: 0000000000201018     0 SECTION LOCAL  DEFAULT   24 
    25: 000000000020102c     0 SECTION LOCAL  DEFAULT   25 
    26: 0000000000000000     0 SECTION LOCAL  DEFAULT   26 
    27: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    28: 0000000000200de8     0 OBJECT  LOCAL  DEFAULT   20 __JCR_LIST__
    29: 0000000000000590     0 FUNC    LOCAL  DEFAULT   13 deregister_tm_clones
    30: 00000000000005d0     0 FUNC    LOCAL  DEFAULT   13 register_tm_clones
    31: 0000000000000620     0 FUNC    LOCAL  DEFAULT   13 __do_global_dtors_aux
    32: 000000000020102c     1 OBJECT  LOCAL  DEFAULT   25 completed.6972
    33: 0000000000200de0     0 OBJECT  LOCAL  DEFAULT   19 __do_global_dtors_aux_fin
    34: 0000000000000660     0 FUNC    LOCAL  DEFAULT   13 frame_dummy
    35: 0000000000200dd8     0 OBJECT  LOCAL  DEFAULT   18 __frame_dummy_init_array_
    36: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS test.cpp
    37: 0000000000000774     4 OBJECT  LOCAL  DEFAULT   15 _ZL13g_static_text
    38: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS crtstuff.c
    39: 00000000000008e8     0 OBJECT  LOCAL  DEFAULT   17 __FRAME_END__
    40: 0000000000200de8     0 OBJECT  LOCAL  DEFAULT   20 __JCR_END__
    41: 0000000000000000     0 FILE    LOCAL  DEFAULT  ABS 
    42: 0000000000000778     0 NOTYPE  LOCAL  DEFAULT   16 __GNU_EH_FRAME_HDR
    43: 0000000000200df0     0 OBJECT  LOCAL  DEFAULT   21 _DYNAMIC
    44: 0000000000200de0     0 NOTYPE  LOCAL  DEFAULT   18 __init_array_end
    45: 0000000000200dd8     0 NOTYPE  LOCAL  DEFAULT   18 __init_array_start
    46: 0000000000201000     0 OBJECT  LOCAL  DEFAULT   23 _GLOBAL_OFFSET_TABLE_
    47: 0000000000201028     4 OBJECT  GLOBAL DEFAULT   24 g_static_data
    48: 000000000020102c     0 NOTYPE  GLOBAL DEFAULT   24 _edata
    49: 0000000000201018     0 NOTYPE  WEAK   DEFAULT   24 data_start
    50: 0000000000000770     4 OBJECT  GLOBAL DEFAULT   15 _IO_stdin_used
    51: 0000000000000690    25 FUNC    GLOBAL DEFAULT   13 _Z9main_funcii
    52: 0000000000000000     0 FUNC    WEAK   DEFAULT  UND __cxa_finalize@@GLIBC_2.2
    53: 00000000000006a9    69 FUNC    GLOBAL DEFAULT   13 main
    54: 0000000000201020     0 OBJECT  GLOBAL HIDDEN    24 __dso_handle
    55: 0000000000000764     0 FUNC    GLOBAL DEFAULT   14 _fini
    56: 0000000000000560    43 FUNC    GLOBAL DEFAULT   13 _start
    57: 0000000000000520     0 FUNC    GLOBAL DEFAULT   10 _init
    58: 0000000000201030     0 OBJECT  GLOBAL HIDDEN    24 __TMC_END__
    59: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _Jv_RegisterClasses
    60: 0000000000201018     0 NOTYPE  GLOBAL DEFAULT   24 __data_start
    61: 0000000000201038     0 NOTYPE  GLOBAL DEFAULT   25 _end
    62: 000000000020102c     0 NOTYPE  GLOBAL DEFAULT   25 __bss_start
    63: 00000000000006f0   101 FUNC    GLOBAL DEFAULT   13 __libc_csu_init
    64: 0000000000201030     4 OBJECT  GLOBAL DEFAULT   25 g_static_bss
    65: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_deregisterTMCloneTab
    66: 0000000000000760     2 FUNC    GLOBAL DEFAULT   13 __libc_csu_fini
    67: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@@GLIBC_
    68: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND __gmon_start__
    69: 0000000000000000     0 NOTYPE  WEAK   DEFAULT  UND _ITM_registerTMCloneTable


.text
0000000000000520 <_init>:
 520:   48 83 ec 08             sub    $0x8,%rsp
 524:   48 8b 05 c5 0a 20 00    mov    0x200ac5(%rip),%rax        # 200ff0 <__gmon_start__>
 52b:   48 85 c0                test   %rax,%rax
 52e:   74 02                   je     532 <_init+0x12>
 530:   ff d0                   callq  *%rax
 532:   48 83 c4 08             add    $0x8,%rsp
 536:   c3                      retq   

Disassembly of section .plt:

0000000000000540 <.plt>:
 540:   ff 35 c2 0a 20 00       pushq  0x200ac2(%rip)        # 201008 <_GLOBAL_OFFSET_TABLE_+0x8>
 546:   ff 25 c4 0a 20 00       jmpq   *0x200ac4(%rip)        # 201010 <_GLOBAL_OFFSET_TABLE_+0x10>
 54c:   0f 1f 40 00             nopl   0x0(%rax)

Disassembly of section .plt.got:

0000000000000550 <.plt.got>:
 550:   ff 25 7a 0a 20 00       jmpq   *0x200a7a(%rip)        # 200fd0 <__cxa_finalize@GLIBC_2.2.5>
 556:   66 90                   xchg   %ax,%ax

Disassembly of section .text:

0000000000000560 <_start>:
 560:   31 ed                   xor    %ebp,%ebp
 562:   49 89 d1                mov    %rdx,%r9
 565:   5e                      pop    %rsi
 566:   48 89 e2                mov    %rsp,%rdx
 569:   48 83 e4 f0             and    $0xfffffffffffffff0,%rsp
 56d:   50                      push   %rax
 56e:   54                      push   %rsp
 56f:   4c 8d 05 ea 01 00 00    lea    0x1ea(%rip),%r8        # 760 <__libc_csu_fini>
 576:   48 8d 0d 73 01 00 00    lea    0x173(%rip),%rcx        # 6f0 <__libc_csu_init>
 57d:   48 8d 3d 25 01 00 00    lea    0x125(%rip),%rdi        # 6a9 <main>
 584:   ff 15 5e 0a 20 00       callq  *0x200a5e(%rip)        # 200fe8 <__libc_start_main@GLIBC_2.2.5>
 58a:   f4                      hlt    
 58b:   0f 1f 44 00 00          nopl   0x0(%rax,%rax,1)

0000000000000590 <deregister_tm_clones>:
 590:   48 8d 3d 99 0a 20 00    lea    0x200a99(%rip),%rdi        # 201030 <__TMC_END__>
 597:   48 8d 05 99 0a 20 00    lea    0x200a99(%rip),%rax        # 201037 <__TMC_END__+0x7>
 59e:   55                      push   %rbp
 59f:   48 29 f8                sub    %rdi,%rax
 5a2:   48 89 e5                mov    %rsp,%rbp
 5a5:   48 83 f8 0e             cmp    $0xe,%rax
 5a9:   76 15                   jbe    5c0 <deregister_tm_clones+0x30>
 5ab:   48 8b 05 2e 0a 20 00    mov    0x200a2e(%rip),%rax        # 200fe0 <_ITM_deregisterTMCloneTable>
 5b2:   48 85 c0                test   %rax,%rax
 5b5:   74 09                   je     5c0 <deregister_tm_clones+0x30>
 5b7:   5d                      pop    %rbp
 5b8:   ff e0                   jmpq   *%rax
 5ba:   66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)
 5c0:   5d                      pop    %rbp
 5c1:   c3                      retq   
 5c2:   0f 1f 40 00             nopl   0x0(%rax)
 5c6:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 5cd:   00 00 00 

00000000000005d0 <register_tm_clones>:
 5d0:   48 8d 3d 59 0a 20 00    lea    0x200a59(%rip),%rdi        # 201030 <__TMC_END__>
 5d7:   48 8d 35 52 0a 20 00    lea    0x200a52(%rip),%rsi        # 201030 <__TMC_END__>
 5de:   55                      push   %rbp
 5df:   48 29 fe                sub    %rdi,%rsi
 5e2:   48 89 e5                mov    %rsp,%rbp
 5e5:   48 c1 fe 03             sar    $0x3,%rsi
 5e9:   48 89 f0                mov    %rsi,%rax
 5ec:   48 c1 e8 3f             shr    $0x3f,%rax
 5f0:   48 01 c6                add    %rax,%rsi
 5f3:   48 d1 fe                sar    %rsi
 5f6:   74 18                   je     610 <register_tm_clones+0x40>
 5f8:   48 8b 05 f9 09 20 00    mov    0x2009f9(%rip),%rax        # 200ff8 <_ITM_registerTMCloneTable>
 5ff:   48 85 c0                test   %rax,%rax
 602:   74 0c                   je     610 <register_tm_clones+0x40>
 604:   5d                      pop    %rbp
 605:   ff e0                   jmpq   *%rax
 607:   66 0f 1f 84 00 00 00    nopw   0x0(%rax,%rax,1)
 60e:   00 00 
 610:   5d                      pop    %rbp
 611:   c3                      retq   
 612:   0f 1f 40 00             nopl   0x0(%rax)
 616:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 61d:   00 00 00 

0000000000000620 <__do_global_dtors_aux>:
 620:   80 3d 05 0a 20 00 00    cmpb   $0x0,0x200a05(%rip)        # 20102c <_edata>
 627:   75 27                   jne    650 <__do_global_dtors_aux+0x30>
 629:   48 83 3d 9f 09 20 00    cmpq   $0x0,0x20099f(%rip)        # 200fd0 <__cxa_finalize@GLIBC_2.2.5>
 630:   00 
 631:   55                      push   %rbp
 632:   48 89 e5                mov    %rsp,%rbp
 635:   74 0c                   je     643 <__do_global_dtors_aux+0x23>
 637:   48 8b 3d e2 09 20 00    mov    0x2009e2(%rip),%rdi        # 201020 <__dso_handle>
 63e:   e8 0d ff ff ff          callq  550 <.plt.got>
 643:   e8 48 ff ff ff          callq  590 <deregister_tm_clones>
 648:   5d                      pop    %rbp
 649:   c6 05 dc 09 20 00 01    movb   $0x1,0x2009dc(%rip)        # 20102c <_edata>
 650:   f3 c3                   repz retq 
 652:   0f 1f 40 00             nopl   0x0(%rax)
 656:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 65d:   00 00 00 

0000000000000660 <frame_dummy>:
 660:   48 8d 3d 81 07 20 00    lea    0x200781(%rip),%rdi        # 200de8 <__JCR_END__>
 667:   48 83 3f 00             cmpq   $0x0,(%rdi)
 66b:   75 0b                   jne    678 <frame_dummy+0x18>
 66d:   e9 5e ff ff ff          jmpq   5d0 <register_tm_clones>
 672:   66 0f 1f 44 00 00       nopw   0x0(%rax,%rax,1)
 678:   48 8b 05 59 09 20 00    mov    0x200959(%rip),%rax        # 200fd8 <_Jv_RegisterClasses>
 67f:   48 85 c0                test   %rax,%rax
 682:   74 e9                   je     66d <frame_dummy+0xd>
 684:   55                      push   %rbp
 685:   48 89 e5                mov    %rsp,%rbp
 688:   ff d0                   callq  *%rax
 68a:   5d                      pop    %rbp
 68b:   e9 40 ff ff ff          jmpq   5d0 <register_tm_clones>

0000000000000690 <_Z9main_funcii>:
 690:   55                      push   %rbp
 691:   48 89 e5                mov    %rsp,%rbp
 694:   89 7d fc                mov    %edi,-0x4(%rbp)
 697:   89 75 f8                mov    %esi,-0x8(%rbp)
 69a:   8b 55 fc                mov    -0x4(%rbp),%edx
 69d:   8b 45 f8                mov    -0x8(%rbp),%eax
 6a0:   01 d0                   add    %edx,%eax
 6a2:   05 c3 07 00 00          add    $0x7c3,%eax
 6a7:   5d                      pop    %rbp
 6a8:   c3                      retq   

00000000000006a9 <main>:
 6a9:   55                      push   %rbp
 6aa:   48 89 e5                mov    %rsp,%rbp
 6ad:   48 83 ec 20             sub    $0x20,%rsp
 6b1:   89 7d ec                mov    %edi,-0x14(%rbp)
 6b4:   48 89 75 e0             mov    %rsi,-0x20(%rbp)
 6b8:   c7 45 fc 00 00 00 00    movl   $0x0,-0x4(%rbp)
 6bf:   48 8d 05 6a 09 20 00    lea    0x20096a(%rip),%rax        # 201030 <__TMC_END__>
 6c6:   8b 55 ec                mov    -0x14(%rbp),%edx
 6c9:   89 10                   mov    %edx,(%rax)
 6cb:   48 8d 05 56 09 20 00    lea    0x200956(%rip),%rax        # 201028 <g_static_data>
 6d2:   8b 10                   mov    (%rax),%edx
 6d4:   48 8d 05 55 09 20 00    lea    0x200955(%rip),%rax        # 201030 <__TMC_END__>
 6db:   8b 00                   mov    (%rax),%eax
 6dd:   89 d6                   mov    %edx,%esi
 6df:   89 c7                   mov    %eax,%edi
 6e1:   e8 aa ff ff ff          callq  690 <_Z9main_funcii>
 6e6:   01 45 fc                add    %eax,-0x4(%rbp)
 6e9:   8b 45 fc                mov    -0x4(%rbp),%eax
 6ec:   c9                      leaveq 
 6ed:   c3                      retq   
 6ee:   66 90                   xchg   %ax,%ax

00000000000006f0 <__libc_csu_init>:
 6f0:   41 57                   push   %r15
 6f2:   41 56                   push   %r14
 6f4:   49 89 d7                mov    %rdx,%r15
 6f7:   41 55                   push   %r13
 6f9:   41 54                   push   %r12
 6fb:   4c 8d 25 d6 06 20 00    lea    0x2006d6(%rip),%r12        # 200dd8 <__frame_dummy_init_array_entry>
 702:   55                      push   %rbp
 703:   48 8d 2d d6 06 20 00    lea    0x2006d6(%rip),%rbp        # 200de0 <__init_array_end>
 70a:   53                      push   %rbx
 70b:   41 89 fd                mov    %edi,%r13d
 70e:   49 89 f6                mov    %rsi,%r14
 711:   4c 29 e5                sub    %r12,%rbp
 714:   48 83 ec 08             sub    $0x8,%rsp
 718:   48 c1 fd 03             sar    $0x3,%rbp
 71c:   e8 ff fd ff ff          callq  520 <_init>
 721:   48 85 ed                test   %rbp,%rbp
 724:   74 20                   je     746 <__libc_csu_init+0x56>
 726:   31 db                   xor    %ebx,%ebx
 728:   0f 1f 84 00 00 00 00    nopl   0x0(%rax,%rax,1)
 72f:   00 
 730:   4c 89 fa                mov    %r15,%rdx
 733:   4c 89 f6                mov    %r14,%rsi
 736:   44 89 ef                mov    %r13d,%edi
 739:   41 ff 14 dc             callq  *(%r12,%rbx,8)
 73d:   48 83 c3 01             add    $0x1,%rbx
 741:   48 39 dd                cmp    %rbx,%rbp
 744:   75 ea                   jne    730 <__libc_csu_init+0x40>
 746:   48 83 c4 08             add    $0x8,%rsp
 74a:   5b                      pop    %rbx
 74b:   5d                      pop    %rbp
 74c:   41 5c                   pop    %r12
 74e:   41 5d                   pop    %r13
 750:   41 5e                   pop    %r14
 752:   41 5f                   pop    %r15
 754:   c3                      retq   
 755:   90                      nop
 756:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
 75d:   00 00 00 

0000000000000760 <__libc_csu_fini>:
 760:   f3 c3                   repz retq 

Disassembly of section .fini:

0000000000000764 <_fini>:
 764:   48 83 ec 08             sub    $0x8,%rsp
 768:   48 83 c4 08             add    $0x8,%rsp
 76c:   c3                      retq   
```