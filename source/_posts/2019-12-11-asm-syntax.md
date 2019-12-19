---
title: 汇编语法/寻址/寄存器/代码模型(GNU assembler)    
date: 2019-12-11
categories: develop 
author: yawei.zhang 
---

### 0.0.1. 目录  

<!-- TOC -->

- [目录](#目录)
- [基础语法格式](#基础语法格式)
- [常见寄存器以及作用](#常见寄存器以及作用)
    - [通用寄存器](#通用寄存器)
        - [寄存器使用惯例 原文](#寄存器使用惯例-原文)
        - [中文对照](#中文对照)
    - [专用寄存器](#专用寄存器)
        - [标志寄存器 RFLAGS](#标志寄存器-rflags)
        - [程序计数器(PC)(Relative Instruction-Pointer)(IP)](#程序计数器pcrelative-instruction-pointerip)
        - [指令寄存器](#指令寄存器)
- [汇编语法](#汇编语法)
    - [汇编指令](#汇编指令)
    - [操作数格式与寻址](#操作数格式与寻址)
        - [内存操作数](#内存操作数)
        - [寻址模式](#寻址模式)
        - [large code mode:](#large-code-mode)
        - [共享库中对g_static_so_data的访问](#共享库中对g_static_so_data的访问)
        - [small code mode:](#small-code-mode)
        - [备注说明](#备注说明)
        - [RELRO  Relocation Read Only](#relro--relocation-read-only)
- [调用惯例Calling Conventions](#调用惯例calling-conventions)
        - [参数压栈顺序](#参数压栈顺序)
            - [Caller Save和Callee Save](#caller-save和callee-save)
- [工具](#工具)
    - [PEDA插件](#peda插件)

<!-- /TOC -->




### 0.0.2. 基础语法格式

GAS汇编的格式阅读起来很自然 如下   
  
```
[操作符]    [源]      [目标]   
movl        $0,      -4(%rbp)  
```


但是INTEL格式更贴近C语言的书写风格   
   
```
[操作符]   [目标]    [源]  
mov        esi,     DWORD PTR [rbp-0x4]
```
  
很像C语言的代码   
   
``` assembly
int esi = *(rbp-0x4);
```

> 本文基于X86-64架构体系整理了GAS风格的汇编语法, 如无特殊说明后续内容皆以环境为准.    

"@"符号表示“将符号左边的变量钳制在符号右边的地址   

<!-- more -->   

### 0.0.3. 常见寄存器以及作用   
16bit寄存器一般没有前缀  例如ax   bx   ds   
32bit寄存器前缀一般为e   例如eax  ebx  eds   
64bit寄存器前缀一般为r   例如rax  rbx  rds

#### 0.0.3.1. 通用寄存器   

X86-64体系下有16个通用寄存器 分别为:
```
rax    rbx    rcx    rdx    rdi    rsi    rbp    rsp    r8 – r15
```
兼容32位模式, 对应为: 
```
eax    ebx    ecx    edx    edi    esi    ebp    esp    e8d – e15d
```

在所有CPU的架构体系中, 每个寄存器通常都是有其建议的使用用途的, X86-64架构下其用途如下:  

##### 0.0.3.1.1. 寄存器使用惯例 原文  
[X86-64 Registers](https://cons.mit.edu/sp17/x86-64-architecture-guide.html)

| Register | Purpose                                | Saved across calls |
| -------- | -------------------------------------- | ------------------ |
| %rax     | temp register; return value            | No                 |
| %rbx     | callee-saved                           | Yes                |
| %rcx     | used to pass 4th argument to functions | No                 |
| %rdx     | used to pass 3rd argument to functions | No                 |
| %rsp     | stack pointer                          | Yes                |
| %rbp     | callee-saved; base pointer             | Yes                |
| %rsi     | used to pass 2nd argument to functions | No                 |
| %rdi     | used to pass 1st argument to functions | No                 |
| %r8      | used to pass 5th argument to functions | No                 |
| %r9      | used to pass 6th argument to functions | No                 |
| %r10-r11 | temporary                              | No                 |
| %r12-r15 | callee-saved registers                 | Yes                |

##### 0.0.3.1.2. 中文对照  
| 寄存器   | 推荐用途                                   | 跨调用过程保存 |
| -------- | ------------------------------------------ | -------------- |
| %rax     | 保存函数/计算的返回值                      | No             |
| %rbx     | callee-saved 基址 (比如找GOT表会临时用下)  | Yes            |
| %rcx     | 函数的第4个参数                            | No             |
| %rdx     | 函数的第3个参数                            | 乘法余数       | No |
| %rsp     | 指向当前栈顶的指针(栈顶)                   | Yes            |
| %rbp     | callee-saved; 指向当前栈帧的起始位置(栈基) | Yes            |
| %rsi     | 函数的第2个参数                            | 字符串源串     | No |
| %rdi     | 函数的第1个参数                            | 字符串目标串   | No |
| %r8      | 函数的第5个参数                            | No             |
| %r9      | 函数的第6个参数                            | No             |
| %r10-r11 | temporary                                  | No             |
| %r12-r15 | callee-saved registers                     | Yes            |

#### 0.0.3.2. 专用寄存器  
标志寄存器和程序计数器可能为同一个寄存器实现  

##### 0.0.3.2.1. 标志寄存器 RFLAGS  

NV UP EI PL NZ NA PO NC表示标志寄存器的值  

| 位编号                           | 1     | 0     |
| -------------------------------- | ----- | ----- |
| 溢出标志OF(Over flow flag)       | OV(1) | NV(0) |
| 方向标志DF(Direction flag)       | DN(1) | UP(0) |
| 中断标志IF(Interrupt flag)       | EI(1) | DI(0) |
| 符号标志SF(Sign flag)            | NG(1) | PL(0) |
| 零标志ZF(Zero flag)              | ZR(1) | NZ(0) |
| 辅助标志AF(Auxiliary carry flag) | AC(1) | NA(0) |
| 奇偶标志PF(Parity flag)          | PE(1) | PO(0) |
| 进位标志CF(Carry flag)           | CY(1) | NC(0) |
| TF(TrapFlag)                     |       |       |

##### 0.0.3.2.2. 程序计数器(PC)(Relative Instruction-Pointer)(IP)  
保存下一行要执行的指令位置  
Intel的实现叫RIP  
> The 64-bit instruction pointer RIP points to the next instruction to be executed, and supports a 64-bit flat memory model.  
> 64位指令指针 RIP 指向预期要执行的下一行指令(位置), 并且支持64位平坦内存模型  
> RIP-relative addressing: this is new for x64 and allows accessing data tables and such in the code relative to the current instruction pointer, making position independent code easier to implement.  
> PIC提供了相对于当前指令位置访问数据表这样新的支持, 从而让PIC更容易实现   

例如PLC表在RIP下的应用  
```
0000000000000570 <foo@plt>:
 570:    ff 25 a2 0a 20 00        jmpq   *0x200aa2(%rip)        # 201018 <_GLOBAL_OFFSET_TABLE_+0x18>
 576:    68 00 00 00 00           pushq  $0x0
 57b:    e9 e0 ff ff ff           jmpq   560 <_init+0x20>
```

在没有RIP的情况下需要通过函数调用来实现PLC  会消耗较多的性能     
windows则直接采用了'重定位基址'的方式实现非PLC的装载.  

##### 0.0.3.2.3. 指令寄存器  
当前正在执行的指令, 简单CPU会预读 但复杂的CPU有流水线/指令级并行计算等    
 



### 0.0.4. 汇编语法   
#### 0.0.4.1. 汇编指令   
 
| 操作码                     | 描述                                                                                       |
| -------------------------- | ------------------------------------------------------------------------------------------ |
| 复制值                     | _                                                                                          |
| mov src, dest              | 将值从 寄存器,立即值或存储器地址 复制到 寄存器或存储器地址, 不可以同时为内存地址           |
| movabs                     | 支持8字节的操作数                                                                          |
| lea src, dest              | move会取值 lea只取地址    dest只能是寄存器                                                 |
| 栈操作                     |                                                                                            |
| enter $x, $0               | 设置堆栈框架 相当于 push ebp      和 mov esp, ebp 然后把当前的esp减去x字节的大小(局部变量) |
| leave                      | 恢复堆栈框架 相当于 move ebp, esp 和 pop ebp                                               |
| push src                   | 将src压栈,  rsp-1并把src的内容存储到新位置. src可以是立即数 寄存器 内存地址                |
| pop dest                   | 出栈并保存到dest 可以是 寄存器 内存地址                                                    |
| 控制流                     |                                                                                            |
| call label                 | 无条件跳转到目标(直接跳转)并将返回地址(当前PC/IP +1)压入堆栈                               |
| call *operand              | 无条件跳转到目标(间接跳转)并将返回地址(当前PC/IP +1)压入堆栈                               |
| ret                        | 将返回地址弹出堆栈 然后无条件跳转到该地址                                                  |
| jmp label                  | 无条件跳转到目标(直接跳转)                                                                 |
| jmp *operand               | 无条件跳转到目标(间接跳转)                                                                 |
| jg, jge, jl, jle, jne, ... | >, >=, <, <=, !=, ...                                                                      |
| 算术与逻辑                 |                                                                                            |
| inc dest                   | dest+=1                                                                                    |
| dec dest                   | dest-=1                                                                                    |
| neg dest                   | dest取负                                                                                   |
| not dest                   | dest取反                                                                                   |
| add src, dest              | dest加上src                                                                                |
| sub src, dest              | dest减去src                                                                                |
| imul src, dest             | dest 乘以src                                                                               |
| idiv divisor               | rdx:rax除以divisor, 将商存在rax 余数存储在rdx                                              |
| shr cl, reg                | reg右移cl位                                                                                |
| shl cl, reg                | reg左移cl位                                                                                |
| ror src, dest              | dest逐src 位向左或向右旋转。                                                               |
| cmp src, dest              | 执行sub操作但只设置标志寄存器而不存储结果                                                  |
| test src, dest             | 执行and操作只设置标志寄存器而不存储结果,其中是否为0的判断一般类似 ```test rax,rax```       |
| and src, dest              | 执行按位的与操作并保存到dest                                                               |
| xor src, dest              | 执行按位的异或操作并保存到dest                                                             |

#### 0.0.4.2. 操作数格式与寻址   

M[xx]表示在存储器中xx地址的值   
R[xx]表示寄存器xx的值   
这种表示方法将寄存器 内存都看出一个大数组的形式    

| 格式         | 操作数值             | 名称              | 样例(GAS = C语言)               |
| ------------ | -------------------- | ----------------- | ------------------------------- |
| %reg         |                      |                   | 寄存器名字前都加 %              |
| $Imm         | Imm                  | 立即数寻址        | $1 = 1                          |
| Ea           | R[Ea]                | 寄存器寻址        | %eax = eax                      |
| Imm          | M[Imm]               | 绝对寻址          | 0x104 = *0x104                  |
| (Ea)         | M[R[Ea]]             | 间接寻址          | (%eax)= *eax                    |
| Imm(Ea)      | M[Imm+R[Ea]]         | (基址+偏移量)寻址 | 4(%eax) = *(4+eax)              |
| (Ea,Eb)      | M[R[Ea]+R[Eb]]       | 变址              | (%eax,%ebx) = *(eax+ebx)        |
| Imm(Ea,Eb)   | M[Imm+R[Ea]+R[Eb]]   | 寻址              | 9(%eax,%ebx)= *(9+eax+ebx)      |
| (,Ea,s)      | M[R[Ea]*s]           | 伸缩化变址寻址    | (,%eax,4)= *(eax*4)             |
| Imm(,Ea,s)   | M[Imm+R[Ea]*s]       | 伸缩化变址寻址    | 0xfc(,%eax,4)= *(0xfc+eax*4)    |
| (Ea,Eb,s)    | M(R[Ea]+R[Eb]*s)     | 伸缩化变址寻址    | (%eax,%ebx,4) = *(eax+ebx*4)    |
| Imm(Ea,Eb,s) | M(Imm+R[Ea]+R[Eb]*s) | 伸缩化变址寻址    | 8(%eax,%ebx,4) = *(8+eax+ebx*4) |

##### 0.0.4.2.1. 内存操作数  

操作数语法:    
```
segment:displacement(base register, index register, scale factor)
```
等效intel语法   
```
segment:[base register + displacement + index register * scale factor]
```
> 如果segment未指定，则几乎总是假定为ds，除非base register为esp或ebp；否则为。在这种情况下，假定地址是相对于ss  
  
> If segment is not specified, as almost always, it is assumed to be ds, unless base register is esp or ebp; in this case, the address is assumed to be relative to ss  
快速参考  

| 指令                   | 含义                                             |
| ---------------------- | ------------------------------------------------ |
| movq %rax, %rbx        | rbx = rax                                        |
| movq $123, %rax        | rax = 123                                        |
| movq %rsi, -16（%rbp） | mem [rbp-16] = rsi                               |
| subq $10, %rbp         | rbp = rbp -10                                    |
| cmpl %eax %ebx         | 比较然后设置标志。如果eax == ebx, 则设置零标志。 |
| leal (%ebx),  %eax     | movl %ebx,  %eax                                 |



##### 0.0.4.2.2. 寻址模式    

> References to both code and data on x64 are done with instruction-relative (RIP-relative in x64 parlance) addressing modes. The offset from RIP in these instructions is limited to 32 bits.     
> X64体系下的寻址是建立在相对寻址(RIP-RELATIVE)之上的, RIP的偏移大小最大为32bits  


[x64 code mode](https://eli.thegreenplace.net/2012/01/03/understanding-the-x64-code-models)    

> Default operand size in 64-bit mode is still 32-bit and 64-bit immediates are allowed only with mov instruction.  
> movabs is just AT&T syntax for a mov with a 64-bit immediate operand.    
> 只有mov操作可以填写8字节的立即数  movabs是AT&T语法中mov的(别名)    

| 指令 | 同义名   | 跳转条件 | 描述     |
| ---- | -------- | -------- | -------- |
| jmp  | Label    | 1        | 直接跳转 |
| jmp  | *Operand | 1        | 间接跳转 |


绝对寻址/直接寻址(Absolute or direct):  

```
jump    address   
```

> (有效PC地址=address)  
> Effective PC address = address  


相对寻址(PC-relative):  
```
jump    offset    
```

> (有效PC地址=rip+offset = 下一个指令的地址 + offset)  
> Effective PC address = next instruction address + offset, offset may be negative  

快速分析:
```
00000000000007e0 <.plt>:
 7e0:   ff 35 22 08 20 00       pushq  0x200822(%rip)        # 201008 <_GLOBAL_OFFSET_TABLE_+0x8>
 7e6:   ff 25 24 08 20 00       jmpq   *0x200824(%rip)        # 201010 <_GLOBAL_OFFSET_TABLE_+0x10>
 7ec:   0f 1f 40 00             nopl   0x0(%rax)
0000000000000810 <_Z12so_func_baseii@plt>:
 810:   ff 25 12 08 20 00       jmpq   *0x200812(%rip)        # 201028 <_Z12so_func_baseii>
 816:   68 02 00 00 00          pushq  $0x2
 81b:   e9 c0 ff ff ff          jmpq   7e0 <.plt>  
 ```

* jmpq   7e0  跳转到 CS:7e0 这个位置  
  > 实际上二进制的内容仍然是相对寻址(81b+5 + -40) ==  7e0  等同 jumpq * -0x40(%rip) 但省了一个字节的指令   

* jmpq   *0x200812(%rip)  跳转到 816 + 0x200812 这个位置 (rip是一个指针 需要解引用获得目标地址)   


```
 a84:   74 20                   je     aa6 <__libc_csu_init+0x56>
 ```
 * 这里跳转指令则只用了两个字节  



##### 0.0.4.2.3. large code mode:  

> In the small code model all addresses (including GOT entries) are accessible via the IP-relative addressing provided by the AMD64 architecture. Hence there is no need for an explicit GOT pointer and therefore no function prologue for setting it up is necessary. In the medium and large code models a register has to be allocated to hold the address of the GOT in position-independent objects, because the AMD64 ISA does not support an immediate displacement larger than 32 bits.  
> 在一个小型代码模型中, 所有的地址(包括GOT入口地址) 都是可以通过IP-RELATIVE访问到.  因此不需要显示声明额外的GOT指针 也不需要设置函数的开始语.  但在一个中型或者大型代码模型中, 必须分配一个寄存器去持有位置无关对象在GOT的地址  (AMD64不支持大于32位的立即跳转)  
 
```
g++-6 -O0 so.so main.cpp lib.cpp -pie -fPIE  -mcmodel=large 
```
 
 举例一个通过.GOT表访问的全局变量代码如下:   
 ```
 a40:   48 8d 1d f9 ff ff ff    lea    -0x7(%rip),%rbx        # a40 <main+0xb>
 a47:   49 bb c0 05 20 00 00    movabs $0x2005c0,%r11
 a4e:   00 00 00 
 a51:   4c 01 db                add    %r11,%rbx
 a54:   89 7d dc                mov    %edi,-0x24(%rbp)
 a57:   48 89 75 d0             mov    %rsi,-0x30(%rbp)
 a5b:   c7 45 ec 00 00 00 00    movl   $0x0,-0x14(%rbp)
 a62:   48 b8 d0 ff ff ff ff    movabs $0xffffffffffffffd0,%rax
 a69:   ff ff ff 
 a6c:   48 8b 04 03             mov    (%rbx,%rax,1),%rax
 a70:   c7 00 e8 03 00 00       movl   $0x3e8,(%rax)
 ```

a4e为8字节的操作数剩余部分

a40行取得当前行的地址 
a51行通过偏移量获得.got表的end 地址 =  a40 + 0x2005c0 =   201000   =.plt.got   (.got表在本测试中大小是0x40)  
a6c行把RBX + 0xffffffffffffffd0 (= -0x30) 得到GOT表中存放全局变量的地址 *(.plt.got -0x30) = got[g_static_so_data]   
a70赋值立即数0x3e8 给全局变量 g_static_so_data = *(got[g_static_so_data])  


节点偏移和大小如下    

| [号] | 名称     | 类型     | 地址     | 偏移量 | 大小  | 全体大小 | 旗标 | 链接 | 信息 | 对齐 |
| ---- | -------- | -------- | -------- | ------ | ----- | -------- | ---- | ---- | ---- | ---- |
| [23] | .got     | PROGBITS | 00200fc0 | 000fc0 | 00040 | 0008     | WA   | 0    | 0    | 8    |
| [24] | .got.plt | PROGBITS | 00201000 | 001000 | 00030 | 0008     | WA   | 0    | 0    | 8    |
| [25] | .data    | PROGBITS | 00201030 | 001030 | 00014 | 0000     | WA   | 0    | 0    | 8    |
| [26] | .bss     | NOBITS   | 00201044 | 001044 | 0000c | 0000     | WA   | 0    | 0    | 4    |

程序声明如下:   
```
extern int g_static_so_bss;
extern int g_static_so_data;
extern int errno;
```
当前汇编访问的是:g_static_so_data   
.dyn global data如下  
```
000000200fc0  000100000006 R_X86_64_GLOB_DAT 0000000000000000 __cxa_finalize@GLIBC_2.2.5 + 0
000000200fc8  000300000006 R_X86_64_GLOB_DAT 0000000000000000 _Jv_RegisterClasses + 0
000000200fd0  000400000006 R_X86_64_GLOB_DAT 0000000000000000 g_static_so_data + 0
000000200fd8  000500000006 R_X86_64_GLOB_DAT 0000000000000000 g_static_so_bss + 0
000000200fe0  000800000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_deregisterTMClone + 0
000000200fe8  000900000006 R_X86_64_GLOB_DAT 0000000000000000 __libc_start_main@GLIBC_2.2.5 + 0
000000200ff0  000a00000006 R_X86_64_GLOB_DAT 0000000000000000 __gmon_start__ + 0
000000200ff8  000b00000006 R_X86_64_GLOB_DAT 0000000000000000 _ITM_registerTMCloneTa + 0
```

##### 0.0.4.2.4. 共享库中对g_static_so_data的访问   
如果代码模型为大型 则和可执行程序中的代码段一致 如果是small或者median 共享库仍然会对全局变量走GOT表  
汇编如下:    
```
 894:   48 8b 05 45 07 20 00    mov    0x200745(%rip),%rax        # 200fe0 <g_static_so_bss@@Base-0x60>
 89b:   48 8b 00                mov    (%rax),%rax
 89e:   01 c2                   add    %eax,%edx
```
894: 取GOT中存储 g_static_so_bss 的项地址 并把内容(g_static_so_bss的地址)存放到%rax中    
89b: 取 g_static_so_bss 的内容  
89e: 加到%edx上  


##### 0.0.4.2.5. small code mode:  
```
g++-6 -O0 so.so main.cpp lib.cpp -pie -fPIE  -mcmodel=small 
```

假设了全局变量的存储位置在低端内存, 因此该全局变量直接定义在主程序的data段, 在so文件中仍然通过.got找到真实地址.    
其类型R_X86_64_COPY  
在主程序的汇编代码只有一行
```
 9f0:   c7 05 4e 06 20 00 e8    movl   $0x3e8,0x20064e(%rip)        # 201048 <g_static_so_data>
```
.dyn global
```
偏移量          信息           类型           符号值        符号名称 + 加数
000000201048  001200000005 R_X86_64_COPY     0000000000201048 g_static_so_data + 0
000000201050  001000000005 R_X86_64_COPY     0000000000201050 g_static_so_bss + 0
```

.dyn so 
```
000000200fd8  001300000006 R_X86_64_GLOB_DAT 0000000000201030 g_static_so_data + 0
000000200fe0  001000000006 R_X86_64_GLOB_DAT 0000000000201040 g_static_so_bss + 0
```

.symver指令
> g_static_so_data@@Base-0x58  的意思是: g_static_so_data的符号值-0x58 也就是g_static_so_data的偏移量  
```
0000000000201030 - 000000200fd8 = 0x58  
```


##### 0.0.4.2.6. 备注说明  
共享库中 无论是large还是small, 都会走so的got表, 区别在于会不会使用movabs进行64位的偏移计算  
got表的位置可能紧接着.text并且设置为只读  
[RELRO](https://systemoverlord.com/2017/03/19/got-and-plt-for-pwning.html)   


通过got表访问全局变量:  
1. 通过RIP-R找到GOT表的位置.   相对于.text固定的偏移量 (large不假定大小)     
2. 通过项索引偏移找到存储该变量地址的地址并解引用得到 变量地址  
   1. (large不假定大小, medium会区分把<64k的数据链接到低内存中 多个数据段.ldata(largedata))  
3. 解引用并使用  
 

```
mov  (%rbx,%rax,1),%rax  
```
这行代码可以优化为一个立即数偏移寻址  即
```
mov    0x200745(%rip),%rax  
```

当前代码段到GOT表的偏移

但是在large模型中 

通过rip寻址的指令中 偏移量不是64位的  因此需要先算一个小的偏移量 再通过支持64bit的 movabs(mov) 添加上一个64bit的偏移

##### 0.0.4.2.7. RELRO  Relocation Read Only   
重定位只读技术  
动态链接器在处理完GOT表后将其设为只读以提高安全性.  

本文测试环境中只读. (实际上这是一个可以成为较为古老的技术了)  
> Linux version 4.9.0-4-amd64 (debian-kernel@lists.debian.org) 
> (gcc version 6.3.0 20170516 (Debian 6.3.0-18) )  
> #1 SMP Debian 4.9.65-3+deb9u1 (2017-12-23)   
> .zsummer  

GOT表为R  只读段.   
.got.plt存储plt的got仍然是读写段 (惰性加载机制决定, 可以选择非惰性+ro来完成全只读化)  




### 0.0.5. 调用惯例Calling Conventions 
计算机中Corotine分两种 Coroutine和Subroutine 前者对应协程 后者对应函数  

* call a routine (trasfer control to procedure)  跳转到目标routine  
* pass arguments  传递参数  
  * fixed length
  * variable length
  * recursively  
* return to the caller  返回调用者地址  
  * putting results in a place where caller an find them  
* manage register  管理寄存器 


##### 0.0.5.0.8. 参数压栈顺序  
标准的linux ABI调用约定中
[System V Application Binary Interface—AMD64 Architecture Processor Supplement]()   


###### 0.0.5.0.8.1. Caller Save和Callee Save   
当产生函数调用时 子函数内通常也会使用到通用寄存器 那么这些寄存器中之前保存的调用者(父函数)的值就会被覆盖   
为了避免数据覆盖而导致从子函数返回时寄存器中的数据不可恢复 CPU 体系结构中就规定了通用寄存器的保存方式   

* Casller Save '调用者保存' 在发起一个调用前需要保存(子例程直接覆盖使用) 
  * 在进入子函数调用前, 调用者需要保存这些寄存器的值.   
    * 一般做法是进入子函数调用前把这些寄存器压入栈中    
* Callee Save '被调用者保存' (子例程使用前需要先保存)   
  * 在进入子函数调用后, 在使用这些寄存器前, 被调用者会保存这些寄存器的内容,并在使用后恢复  
  * 这种比较特殊也比较麻烦, 因为一旦接受这个设定, 那么所有subroutine都要进行合适的push并保证pop恢复.     
  * 

* cross

### 0.0.6. 工具   

* objdump -S 查看汇编指令  
* gdb  
  * gdb 通过```  layout regs  ```打开寄存器显示, 通过```set disassemble-next-line on```打开汇编  
  * gdb 通过peda插件字节显示汇编和寄存器  和上面的原生方式选择一个即可, peda默认显示是intex语法    
  * disas反汇编命令,直接disas是反汇编当前函数
    * disas /r (显示汇编指令对应十六进制值)   
    * disas /m (如果有源码,显示对应行源码)   
  * intel语法
    * set disassembly-flavor intel
    * set disassembly-flavor att
  * gdb关闭ASLR：
    * set disable-randomization on
  * 开启ASLR：
    * set disable-randomization off
  * 查看ASLR状态：
    * show disable-randomization
  * 查看二进制  
    * ```x /1ag addr```

#### 0.0.6.1. PEDA插件  
peda默认设置的是intel的语法风格
```
git clone https://github.com/longld/peda.git ~/peda
echo "source ~/peda/peda.py" >> ~/.gdbinit
echo "DONE! debug your program with gdb and enjoy"
```
* aslr -- Show/set ASLR setting of GDB
* checksec -- Check for various security options of binary
* dumpargs -- Display arguments passed to a function when stopped at a call instruction
* dumprop -- Dump all ROP gadgets in specific memory range
* elfheader -- Get headers information from debugged ELF file
* elfsymbol -- Get non-debugging symbol information from an ELF file
* lookup -- Search for all addresses/references to addresses which belong to a memory range
* patch -- Patch memory start at an address with string/hexstring/int
* pattern -- Generate, search, or write a cyclic pattern to memory
* procinfo -- Display various info from /proc/pid/
* pshow -- Show various PEDA options and other settings
* pset -- Set various PEDA options and other settings
* readelf -- Get headers information from an ELF file
* ropgadget -- Get common ROP gadgets of binary or library
* ropsearch -- Search for ROP gadgets in memory
* searchmem|find -- Search for a pattern in memory; support regex search
* shellcode -- Generate or download common shellcodes.
* skeleton -- Generate python exploit code template
* vmmap -- Get virtual mapping address ranges of section(s) in debugged process
* xormem -- XOR a memory region with a key
