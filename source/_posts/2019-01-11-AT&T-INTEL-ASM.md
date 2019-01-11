---
title: AT&T 和 INTEL 汇编格式区别  
date: 2019-01-11 17:21:00
categories: develop 
---

### 一、AT&T 格式Linux 汇编语法格式


* 在 AT&T 汇编格式中，寄存器名要加上 '%' 作为前缀；而在 Intel 汇编格式中，寄存器名不需要加前缀。例如：  

|       AT&T格式       |         Intel格式           |
|       -------       |        -----------          |
|   pushl %eax        |           push eax          |

  <!-- more -->  

* 在 AT&T 汇编格式中，用 '$' 前缀表示一个立即操作数；而在 Intel 汇编格式中，立即数的表示不用带任何前缀。例如：  

|       AT&T格式       |         Intel格式           |
|       -------       |        -----------          |
|       pushl $1       |           push 1            |


* AT&T 和 Intel 格式中的源操作数和目标操作数的位置正好相反。在 Intel 汇编格式中，目标操作数在源操作数的左边；而在 AT&T 汇编格式中，目标操作数在源操作数的右边。例如：  

|       AT&T格式       |         Intel格式           |
|       -------        |        -----------          |
|      addl $1, %eax   |         add eax, 1          |



* 在 AT&T 汇编格式中，操作数的字长由操作符的最后一个字母决定，后缀'b'、'w'、'l'分别表示操作数为字节（byte，8 比特）、字（word，16 比特）和长字（long，32比特）；而在 Intel 汇编格式中，操作数的字长是用 "byte ptr" 和 "word ptr" 等前缀来表示的。例如：

|       AT&T格式       |         Intel格式                   |
|       -------        |        -----------                  |
|      movb val, %al   |         mov al, byte ptr val        |


* 在 AT&T 汇编格式中，绝对转移和调用指令（jump/call）的操作数前要加上'*'作为前缀，而在 Intel 格式中则不需要。  
* 远程转移指令和远程子调用指令的操作码，在 AT&T 汇编格式中为 "ljump" 和 "lcall"，而在 Intel 汇编格式中则为 "jmp far" 和 "call far"，即：  

|       AT&T格式                    |         Intel格式                   |
|       -------                     |        -----------                  |
|      ljump $section, $offset      |        jmp far section:offset       |
|     lcall $section, $offset       |        call far section:offset      |


* 与之相应的远程返回指令则为：

|       AT&T格式               |         Intel格式                 |
|       -------                 |        -----------             |
|      lret $stack_adjust      |        ret far stack_adjust      |


* 内存操作数的寻址方式  

|       AT&T格式                             |         Intel格式                                 |
|       -------                              |        -----------                               |
|      section:disp(base, index, scale)      |        section:[base + index*scale + disp]      |



* 由于 Linux 工作在保护模式下，用的是 32 位线性地址，所以在计算地址时不用考虑段基址和偏移量，而是采用如下的地址计算方法：
```
disp + base + index * scale
```

* 下面是一些内存操作数的例子：  

|       AT&T格式                             |          Intel格式                                 |
|       -------                             |          -----------                               |
|      movl -4(%ebp), %eax                  |          mov eax, [ebp - 4]                       |
|      movl array(, %eax, 4), %eax          |          mov eax, [eax*4 + array]                 |
|      movw array(%ebx, %eax, 4), %cx       |          mov cx, [ebx + 4*eax + array]              |
|      movb $4, %fs:(%eax)                  |          mov fs:eax, 4                             |




### 二、Hello World!

既然所有程序设计语言的第一个例子都是在屏幕上打印一个字符串 "Hello World!"，那我们也以这种方式来开始介绍 Linux 下的汇编语言程序设计。  

在 Linux 操作系统中，你有很多办法可以实现在屏幕上显示一个字符串，但最简洁的方式是使用 Linux 内核提供的系统调用。使用这种方法最大的好处是可以直接和操作系统的内核进行通讯，不需要链接诸如 libc 这样的函数库，也不需要使用 ELF 解释器，因而代码尺寸小且执行速度快。  

Linux 是一个运行在保护模式下的 32 位操作系统，采用 flat memory 模式，目前最常用到的是 ELF 格式的二进制代码。一个 ELF 格式的可执行程序通常划分为如下几个部分：.text、.data 和 .bss，其中 .text 是只读的代码区，.data 是可读可写的数据区，而 .bss 则是可读可写且没有初始化的数据区。代码区和数据区在 ELF 中统称为 section，根据实际需要你可以使用其它标准的 section，也可以添加自定义 section，但一个 ELF 可执行程序至少应该有一个 .text 部分。下面给出我们的第一个汇编程序，用的是 AT&T 汇编语言格式：   

###### 例1. AT&T 格式

* #hello.s
```
.data                    # 数据段声明

        msg : .string "Hello, world!\\n" # 要输出的字符串

        len = . - msg                   # 字串长度

.text                    # 代码段声明

.global _start           # 指定入口函数

_start:                  # 在屏幕上显示一个字符串

        movl $len, %edx  # 参数三：字符串长度

        movl $msg, %ecx  # 参数二：要显示的字符串

        movl $1, %ebx    # 参数一：文件描述符(stdout)

        movl $4, %eax    # 系统调用号(sys_write)

        int  $0x80       # 调用内核功能

                         # 退出程序

        movl $0,%ebx     # 参数一：退出代码

        movl $1,%eax     # 系统调用号(sys_exit)

        int  $0x80       # 调用内核功能
```

初次接触到 AT&T 格式的汇编代码时，很多程序员都认为太晦涩难懂了，没有关系，在 Linux 平台上你同样可以使用 Intel 格式来编写汇编程序：

###### 例2. Intel 格式

; hello.asm
```
section .data            ; 数据段声明

        msg db "Hello, world!", 0xA     ; 要输出的字符串

        len equ $ - msg                 ; 字串长度

section .text            ; 代码段声明

global _start            ; 指定入口函数

_start:                  ; 在屏幕上显示一个字符串

        mov edx, len     ; 参数三：字符串长度

        mov ecx, msg     ; 参数二：要显示的字符串

        mov ebx, 1       ; 参数一：文件描述符(stdout)

        mov eax, 4       ; 系统调用号(sys_write)

        int 0x80         ; 调用内核功能

                         ; 退出程序

        mov ebx, 0       ; 参数一：退出代码

        mov eax, 1       ; 系统调用号(sys_exit)

        int 0x80         ; 调用内核功能
```

上面两个汇编程序采用的语法虽然完全不同，但功能却都是调用 Linux 内核提供的 sys_write 来显示一个字符串，然后再调用 sys_exit 退出程序。在 Linux 内核源文件 include/asm-i386/unistd.h 中，可以找到所有系统调用的定义。

### 四、系统调用

即便是最简单的汇编程序，也难免要用到诸如输入、输出以及退出等操作，而要进行这些操作则需要调用操作系统所提供的服务，也就是系统调用。除非你的程序只完成加减乘除等数学运算，否则将很难避免使用系统调用，事实上除了系统调用不同之外，各种操作系统的汇编编程往往都是很类似的。

在 Linux 平台下有两种方式来使用系统调用：利用封装后的 C 库（libc）或者通过汇编直接调用。其中通过汇编语言来直接调用系统调用，是最高效地使用 Linux 内核服务的方法，因为最终生成的程序不需要与任何库进行链接，而是直接和内核通信。

和 DOS 一样，Linux 下的系统调用也是通过中断（int 0x80）来实现的。在执行 int 80 指令时，寄存器 eax 中存放的是系统调用的功能号，而传给系统调用的参数则必须按顺序放到寄存器 ebx，ecx，edx，esi，edi 中，当系统调用完成之后，返回值可以在寄存器 eax 中获得。

所有的系统调用功能号都可以在文件 /usr/include/bits/syscall.h 中找到，为了便于使用，它们是用 SYS_<name> 这样的宏来定义的，如 SYS_write、SYS_exit 等。例如，经常用到的 write 函数是如下定义的：
```
ssize_t write(int fd, const void *buf, size_t count);
```
该函数的功能最终是通过 SYS_write 这一系统调用来实现的。根据上面的约定，参数 fb、buf 和 count 分别存在寄存器 ebx、ecx 和 edx 中，而系统调用号 SYS_write 则放在寄存器 eax 中，当 int 0x80 指令执行完毕后，返回值可以从寄存器 eax 中获得。

或许你已经发现，在进行系统调用时至多只有 5 个寄存器能够用来保存参数，难道所有系统调用的参数个数都不超过 5 吗？当然不是，例如 mmap 函数就有 6 个参数，这些参数最后都需要传递给系统调用 SYS_mmap：
```
void * mmap(void *start, size_t length, int prot , int flags, int fd, off_t offset);c
```
当一个系统调用所需的参数个数大于 5 时，执行int 0x80 指令时仍需将系统调用功能号保存在寄存器 eax 中，所不同的只是全部参数应该依次放在一块连续的内存区域里，同时在寄存器 ebx 中保存指向该内存区域的指针。系统调用完成之后，返回值仍将保存在寄存器 eax 中。

由于只是需要一块连续的内存区域来保存系统调用的参数，因此完全可以像普通的函数调用一样使用栈(stack)来传递系统调用所需的参数。但要注意一点， Linux 采用的是 C 语言的调用模式，这就意味着所有参数必须以相反的顺序进栈，即最后一个参数先入栈，而第一个参数则最后入栈。如果采用栈来传递系统调用所需的参数，在执行 int 0x80 指令时还应该将栈指针的当前值复制到寄存器 ebx中。

### 五、命令行参数

在 Linux 操作系统中，当一个可执行程序通过命令行启动时，其所需的参数将被保存到栈中：首先是 argc，然后是指向各个命令行参数的指针数组 argv，最后是指向环境变量的指针数据 envp。在编写汇编语言程序时，很多时候需要对这些参数进行处理，下面的代码示范了如何在汇编代码中进行命令行参数的处理：

例3. 处理命令行参数

##### args.S
```
.text

.globl _start

_start:

popl %ecx # argc

vnext:

popl %ecx # argv

test %ecx, %ecx # 空指针表明结束

jz exit

movl %ecx, %ebx

xorl %edx, %edx

strlen:

movb (%ebx), %al

inc %edx

inc %ebx

test %al, %al

jnz strlen

movb $10, -1(%ebx)

movl $4, %eax # 系统调用号(sys_write)

movl $1, %ebx # 文件描述符(stdout)

int $0x80

jmp vnext

exit: movl $1,%eax # 系统调用号(sys_exit)

xorl %ebx, %ebx # 退出代码

int $0x80

ret
```

### 六、GCC 内联汇编

用汇编编写的程序虽然运行速度快，但开发速度非常慢，效率也很低。如果只是想对关键代码段进行优化，或许更好的办法是将汇编指令嵌入到 C 语言程序中，从而充分利用高级语言和汇编语言各自的特点。但一般来讲，在 C 代码中嵌入汇编语句要比"纯粹"的汇编语言代码复杂得多，因为需要解决如何分配寄存器，以及如何与C代码中的变量相结合等问题。

GCC 提供了很好的内联汇编支持，最基本的格式是：
```
__asm__("asm statements");
```
例如：
```
__asm__("nop");
```
如果需要同时执行多条汇编语句，则应该用"\\n\\t"将各个语句分隔开，例如：
```
__asm__( "pushl %%eax \\n\\t"

"movl $0, %%eax \\n\\t"

"popl %eax");
```
通常嵌入到 C 代码中的汇编语句很难做到与其它部分没有任何关系，因此更多时候需要用到完整的内联汇编格式：
```
__asm__("asm statements" : outputs : inputs : registers-modified);
```
插入到 C 代码中的汇编语句是以":"分隔的四个部分，其中第一部分就是汇编代码本身，通常称为指令部，其格式和在汇编语言中使用的格式基本相同。指令部分是必须的，而其它部分则可以根据实际情况而省略。

在将汇编语句嵌入到C代码中时，操作数如何与C代码中的变量相结合是个很大的问题。GCC采用如下方法来解决这个问题：程序员提供具体的指令，而对寄存器的使用则只需给出"样板"和约束条件就可以了，具体如何将寄存器与变量结合起来完全由GCC和GAS来负责。

在GCC 内联汇编语句的指令部中，加上前缀''%''的数字(如%0，%1)表示的就是需要使用寄存器的"样板"操作数。指令部中使用了几个样板操作数，就表明有几个变量需要与寄存器相结合，这样GCC和GAS在编译和汇编时会根据后面给定的约束条件进行恰当的处理。由于样板操作数也使用'' %''作为前缀，因此在涉及到具体的寄存器时，寄存器名前面应该加上两个''%''，以免产生混淆。

紧跟在指令部后面的是输出部，是规定输出变量如何与样板操作数进行结合的条件，每个条件称为一个"约束"，必要时可以包含多个约束，相互之间用逗号分隔开就可以了。每个输出约束都以''=''号开始，然后紧跟一个对操作数类型进行说明的字后，最后是如何与变量相结合的约束。凡是与输出部中说明的操作数相结合的寄存器或操作数本身，在执行完嵌入的汇编代码后均不保留执行之前的内容，这是GCC在调度寄存器时所使用的依据。

输出部后面是输入部，输入约束的格式和输出约束相似，但不带''=''号。如果一个输入约束要求使用寄存器，则GCC在预处理时就会为之分配一个寄存器，并插入必要的指令将操作数装入该寄存器。与输入部中说明的操作数结合的寄存器或操作数本身，在执行完嵌入的汇编代码后也不保留执行之前的内容。

有时在进行某些操作时，除了要用到进行数据输入和输出的寄存器外，还要使用多个寄存器来保存中间计算结果，这样就难免会破坏原有寄存器的内容。在GCC内联汇编格式中的最后一个部分中，可以对将产生副作用的寄存器进行说明，以便GCC能够采用相应的措施。

下面是一个内联汇编的简单例子：

###### 例4.内联汇编
```
int main()
{
    int a = 10, b = 0;

    __asm__ __volatile__("movl %1, %%eax;\\n\\r"

    "movl %%eax, %0;"

    :"=r"(b)

    :"r"(a)

    :"%eax");

    printf("Result: %d, %d\\n", a, b);
}
```

上面的程序完成将变量a的值赋予变量b，有几点需要说明：

变量b是输出操作数，通过%0来引用，而变量a是输入操作数，通过%1来引用。
输入操作数和输出操作数都使用r进行约束，表示将变量a和变量b存储在寄存器中。输入约束和输出约束的不同点在于输出约束多一个约束修饰符''=''。
在内联汇编语句中使用寄存器eax时，寄存器名前应该加两个''%''，即%%eax。内联汇编中使用%0、%1等来标识变量，任何只带一个''%''的标识符都看成是操作数，而不是寄存器。
内联汇编语句的最后一个部分告诉GCC它将改变寄存器eax中的值，GCC在处理时不应使用该寄存器来存储任何其它的值。
由于变量b被指定成输出操作数，当内联汇编语句执行完毕后，它所保存的值将被更新。
在内联汇编中用到的操作数从输出部的第一个约束开始编号，序号从0开始，每个约束记数一次，指令部要引用这些操作数时，只需在序号前加上''%''作为前缀就可以了。需要注意的是，内联汇编语句的指令部在引用一个操作数时总是将其作为32位的长字使用，但实际情况可能需要的是字或字节，因此应该在约束中指明正确的限定符：


|                限定符                 |            意义          
|                -----                 |            -----          
|                "m"、"v"、"o"          |            内存单元        
|                "r"                    |            任何寄存器         
|                "q"                    |            寄存器eax、ebx、ecx、edx之一     
|                "i"、"h"               |            直接操作数          
|                "E"和"F"               |            浮点数           
|                "g"                    |            任意          
|                "a"、"b"、"c"、"d"      |            分别表示寄存器eax、ebx、ecx和edx          
|                "S"和"D"               |            寄存器esi、edi          
|                "I"                    |            常数（0至31）         




### 七.  LIBCO协程的swap代码  
```
.globl coctx_swap
#if !defined( __APPLE__ )
.type  coctx_swap, @function
#endif
coctx_swap:

#if defined(__i386__)
	leal 4(%esp), %eax //sp 
	movl 4(%esp), %esp 
	leal 32(%esp), %esp //parm a : &regs[7] + sizeof(void*)

	pushl %eax //esp ->parm a 

	pushl %ebp
	pushl %esi
	pushl %edi
	pushl %edx
	pushl %ecx
	pushl %ebx
	pushl -4(%eax)

	
	movl 4(%eax), %esp //parm b -> &regs[0]

	popl %eax  //ret func addr
	popl %ebx  
	popl %ecx
	popl %edx
	popl %edi
	popl %esi
	popl %ebp
	popl %esp
	pushl %eax //set ret func addr

	xorl %eax, %eax
	ret

#elif defined(__x86_64__)
	leaq 8(%rsp),%rax
	leaq 112(%rdi),%rsp
	pushq %rax
	pushq %rbx
	pushq %rcx
	pushq %rdx

	pushq -8(%rax) //ret func addr

	pushq %rsi
	pushq %rdi
	pushq %rbp
	pushq %r8
	pushq %r9
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	
	movq %rsi, %rsp
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %r9
	popq %r8
	popq %rbp
	popq %rdi
	popq %rsi
	popq %rax //ret func addr
	popq %rdx
	popq %rcx
	popq %rbx
	popq %rsp
	pushq %rax
	
	xorl %eax, %eax
	ret
#endif

```

使用方式:  
```

#define ESP 0
#define EIP 1
#define EAX 2
#define ECX 3
// -----------
#define RSP 0
#define RIP 1
#define RBX 2
#define RDI 3
#define RSI 4

#define RBP 5
#define R12 6
#define R13 7
#define R14 8
#define R15 9
#define RDX 10
#define RCX 11
#define R8 12
#define R9 13


//----- --------
// 32 bit
// | regs[0]: ret |
// | regs[1]: ebx |
// | regs[2]: ecx |
// | regs[3]: edx |
// | regs[4]: edi |
// | regs[5]: esi |
// | regs[6]: ebp |
// | regs[7]: eax |  = esp
enum
{
	kEIP = 0,
	kESP = 7,
};

//-------------
// 64 bit
//low | regs[0]: r15 |
//    | regs[1]: r14 |
//    | regs[2]: r13 |
//    | regs[3]: r12 |
//    | regs[4]: r9  |
//    | regs[5]: r8  | 
//    | regs[6]: rbp |
//    | regs[7]: rdi |
//    | regs[8]: rsi |
//    | regs[9]: ret |  //ret func addr
//    | regs[10]: rdx |
//    | regs[11]: rcx | 
//    | regs[12]: rbx |
//hig | regs[13]: rsp |
enum
{
	kRDI = 7,
	kRSI = 8,
	kRETAddr = 9,
	kRSP = 13,
};

int coctx_make( coctx_t *ctx,coctx_pfn_t pfn,const void *s,const void *s1 )
{
	char *sp = ctx->ss_sp + ctx->ss_size;
	sp = (char*) ((unsigned long)sp & -16LL  );

	memset(ctx->regs, 0, sizeof(ctx->regs));

	ctx->regs[ kRSP ] = sp - 8;

	ctx->regs[ kRETAddr] = (char*)pfn;

	ctx->regs[ kRDI ] = (char*)s;
	ctx->regs[ kRSI ] = (char*)s1;
	return 0;
}

int coctx_init( coctx_t *ctx )
{
	memset( ctx,0,sizeof(*ctx));
	return 0;
}

extern "C"
{
    extern void coctx_swap(coctx_t *, coctx_t*) asm("coctx_swap");
};

coctx_init(&worker.ctx);
coctx_make(&worker.ctx, stress, (void*)0, &worker);
clock_t start = clock();
for (int i = 0; i < 1000 * 10000; ++i)
{
    coctx_swap(&main_co.ctx, &worker.ctx);
}

```















