
---
title: OI卡常优化     
date: 2021-11-15
categories: develop 
author: yawei.zhang 
mathjax: false
---

# gcc-3.4.6为参考   



## O0
不做任何优化, 这是默认的编译选项.  

## O1 
-O和-O1:  对程序做部分编译优化, 对于大函数,优化编译占用稍微多的时间和相当大的内存. 使用本项优化, 编译器会尝试减小生成代码的尺寸, 以及缩短执行时间, 但并不执行需要占用大量编译时间的优化.  

* fdefer-pop: 延迟栈的弹出时间. 当完成一个函数调用, 参数并不马上从栈中弹出, 而是在多个函数被调用后, 一次性弹出.    

* fmerge-constants: 尝试横跨编译单元合并同样的常量(string constants and floating point constants)   

* fthread-jumps: 如果某个跳转分支的目的地存在另一个条件比较,而且该条件比较包含在前一个比较语句之内,那么执行本项优化.根据条件是true或者false,前面那条分支重定向到第二条分支的目的地或者紧跟在第二条分支后面. 

* floop-optimize: 执行循环优化,将常量表达式从循环中移除, 简化判断循环的条件, 并且optionally do strength-reduction, 或者将循环打开等. 在大型复杂的循环中, 这种优化比较显著.  

* fif-conversion: 尝试将条件跳转转换为等价的无分支型式. 优化实现方式包括条件移动, min, max, 设置标志, 以及abs指令, 以及一些算术技巧等.   

* fif-conversion2基本意义相同, 没有找到更多的解释.  

* fdelayed-branch: 这种技术试图根据指令周期时间重新安排指令.  它还试图把尽可能多的指令移动到条件分支前, 以便最充分的利用处理器的治理缓存.  

* fguess-branch-probability: 当没有可用的profiling feedback或__builtin_expect时, 编译器采用随机模式猜测分支被执行的可能性, 并移动对应汇编代码的位置, 这有可能导致不同的编译器会编译出迥然不同的目标代码.  

* fcprop-registers: 因为在函数中把寄存器分配给变量, 所以编译器执行第二次检查以便减少调度依赖性(两个段要求使用相同的寄存器)并且删除不必要的寄存器复制操作.  

<!-- more -->
## -O2
比O1更高级的选项, 进行更多的优化. Gcc将执行几乎所有的不包含时间和空间折中的优化.    
当设置O2选项时, 编译器并不进行循环打开（）loop unrolling以及函数内联.   
与O1比较而言, O2优化增加了编译时间的基础上, 提高了生成代码的执行效率.    
O2打开所有的O1选项, 并打开以下选项:  

* fforce-mem: 在做算术操作前, 强制将内存数据copy到寄存器中以后再执行. 这会使所有的内存引用潜在的共同表达式, 进而产出更高效的代码, 当没有共同的子表达式时, 指令合并将排出个别的寄存器载入. 这种优化对于只涉及单一指令的变量, 这样也许不会有很大的优化效果. 但是对于再很多指令(必须数学操作)中都涉及到的变量来说, 这会时很显著的优化, 因为和访问内存中的值相比 ,处理器访问寄存器中的值要快的多.  

* foptimize-sibling-calls: 优化相关的以及末尾递归的调用. 通常, 递归的函数调用可以被展开为一系列一般的指令,  而不是使用分支.  这样处理器的指令缓存能够加载展开的指令并且处理他们, 和指令保持为需要分支操作的单独函数调用相比, 这样更快.  

* fstrength-reduce: 这种优化技术对循环执行优化并且删除迭代变量.  迭代变量是捆绑到循环计数器的变量, 比如使用变量, 然后使用循环计数器变量执行数学操作的for-next循环.  

* fcse-follow-jumps: 在公用子表达式消元时, 当目标跳转不会被其他路径可达, 则扫描整个的跳转表达式. 例如, 当公用子表达式消元时遇到if...else...语句时, 当条为false时, 那么公用子表达式消元会跟随着跳转.    

* fcse-skip-blocks: 与-fcse-follow-jumps类似, 不同的是, 根据特定条件, 跟随着cse跳转的会是整个的blocks 

* frerun-cse-after-loop: 在循环优化完成后, 重新进行公用子表达式消元操作.  

* frerun-loop-opt: 两次运行循环优化 * fgcse: 执行全局公用子表达式消除pass. 这个pass还执行全局常量和copy propagation. 这些优化操作试图分析生成的汇编语言代码并且结合通用片段,  消除冗余的代码段. 如果代码使用计算性的goto, gcc指令推荐使用-fno-gcse选项.  

l-fgcse-lm: 全局公用子表达式消除将试图移动那些仅仅被自身存储kill的装载操作的位置. 这将允许将循环内的load/store操作序列中的load转移到循环的外面（只需要装载一次）, 而在循环内改变成copy/store序列. 在选中-fgcse后, 默认打开.  

* fgcse-sm: 当一个存储操作pass在一个全局公用子表达式消除的后面, 这个pass将试图将store操作转移到循环外面去. 如果与-fgcse-lm配合使用, 那么load/store操作将会转变为在循环前load, 在循环后store, 从而提高运行效率, 减少不必要的操作.  

* fgcse-las: 全局公用子表达式消除pass将消除在store后面的不必要的load操作, 这些load与store通常是同一块存储单元（全部或局部） 

l-fdelete-null-pointer-checks: 通过对全局数据流的分析, 识别并排出无用的对空指针的检查. 编译器假设间接引用空指针将停止程序.  如果在间接引用之后检查指针, 它就不可能为空.  

* fexpensive-optimizations: 进行一些从编译的角度来说代价高昂的优化（这种优化据说对于程序执行未必有很大的好处, 甚至有可能降低执行效率, 具体不是很清楚） 

* fregmove: 编译器试图重新分配move指令或者其他类似操作数等简单指令的寄存器数目, 以便最大化的捆绑寄存器的数目. 这种优化尤其对双操作数指令的机器帮助较大.  

* fschedule-insns: 编译器尝试重新排列指令, 用以消除由于等待未准备好的数据而产生的延迟. 这种优化将对慢浮点运算的机器以及需要load memory的指令的执行有所帮助, 因为此时允许其他指令执行, 直到load memory的指令完成, 或浮点运算的指令再次需要cpu.  l 

-fschedule-insns2: 与-fschedule-insns相似. 但是当寄存器分配完成后, 会请求一个附加的指令计划pass. 这种优化对寄存器较小, 并且load memory操作时间大于一个时钟周期的机器有非常好的效果.  

* fsched-interblock: 这种技术使编译器能够跨越指令块调度指令.  这可以非常灵活地移动指令以便等待期间完成的工作最大化.  

* fsched-spec-load: 允许一些load指令进行一些投机性的动作. （具体不详）相同功能的还有-fsched-spec-load-dangerous, 允许更多的load指令进行投机性操作. 这两个选项在选中-fschedule-insns时默认打开.  

* fcaller-saves: 通过存储和恢复call调用周围寄存器的方式, 使被call调用的value可以被分配给寄存器, 这种只会在看上去能产生更好的代码的时候才被使用. （如果调用多个函数, 这样能够节省时间, 因为只进行一次寄存器的保存和恢复操作, 而不是在每个函数调用中都进行. ） 

* fpeephole2: 允许计算机进行特定的观察孔优化(这个不晓得是什么意思), -fpeephole与-fpeephole2的差别在于不同的编译器采用不同的方式, 由的采用-fpeephole, 有的采用-fpeephole2, 也有两种都采用的.  

* freorder-blocks: 在编译函数的时候重新安排基本的块, 目的在于减少分支的个数, 提高代码的局部性.  

* freorder-functions: 在编译函数的时候重新安排基本的块, 目的在于减少分支的个数, 提高代码的局部性. 这种优化的实施依赖特定的已存在的信息: .text.hot用于告知访问频率较高的函数, .text.unlikely用于告知基本不被执行的函数.  

* fstrict-aliasing: 这种技术强制实行高级语言的严格变量规则.  对于c和c++程序来说, 它确保不在数据类型之间共享变量. 例如, 整数变量不和单精度浮点变量使用相同的内存位置.  

* funit-at-a-time: 在代码生成前, 先分析整个的汇编语言代码. 这将使一些额外的优化得以执行, 但是在编译器间需要消耗大量的内存. （有资料介绍说: 这使编译器可以重新安排不消耗大量时间的代码以便优化指令缓存. ） 

* falign-functions: 这个选项用于使函数对准内存中特定边界的开始位置.  大多数处理器按照页面读取内存, 并且确保全部函数代码位于单一内存页面内, 就不需要叫化代码所需的页面.  

* falign-jumps: 对齐分支代码到2的n次方边界. 在这种情况下, 无需执行傀儡指令（dummy operations） 

* falign-loops: 对齐循环到2的n次幂边界. 期望可以对循环执行多次, 用以补偿运行dummy operations所花费的时间.  

* falign-labels: 对齐分支到2的n次幂边界. 这种选项容易使代码速度变慢, 原因是需要插入一些dummy operations当分支抵达usual flow of the code. 

* fcrossjumping: 这是对跨越跳转的转换代码处理,  以便组合分散在程序各处的相同代码.  这样可以减少代码的长度,  但是也许不会对程序性能有直接影响.   



## -O3
比O2更进一步的进行优化. 

在包含了O2所有的优化的基础上, 又打开了以下优化选项:  

* finline-functions: 内联简单的函数到被调用函数中. 由编译器启发式的决定哪些函数足够简单可以做这种内联优化. 默认情况下, 编译器限制内联的尺寸, 3.4.6中限制为600（具体含义不详, 指令条数或代码size？）可以通过-finline-limit=n改变这个长度. 这种优化技术不为函数创建单独的汇编语言代码,  而是把函数代码包含在调度程序的代码中.  对于多次被调用的函数来说, 为每次函数调用复制函数代码.  虽然这样对于减少代码长度不利, 但是通过最充分的利用指令缓存代码, 而不是在每次函数调用时进行分支操作, 可以提高性能.  

* fweb: 构建用于保存变量的伪寄存器网络.  伪寄存器包含数据, 就像他们是寄存器一样, 但是可以使用各种其他优化技术进行优化, 比如cse和loop优化技术. 这种优化会使得调试变得更加的不可能, 因为变量不再存放于原本的寄存器中.  

* frename-registers: 在寄存器分配后, 通过使用registers left over来避免预定代码中的虚假依赖. 这会使调试变得非常困难, 因为变量不再存放于原本的寄存器中了.  

* funswitch-loops: 将无变化的条件分支移出循环, 取而代之的将结果副本放入循环中.  



 ## -Os
 主要是对程序的尺寸进行优化. 打开了大部分O2优化中不会增加程序大小的优化选项, 并对程序代码的大小做更深层的优化. （通常我们不需要这种优化）Os会关闭如下选项:  -falign-functions -falign-jumps -falign-loops  -falign-labels   -freorder-blocks   -fprefetch-loop-arrays  

## -Og
该标识会精心挑选部分与-g选项不冲突的优化选项, 当然就能提供合理的优化水平, 同时产生较好的可调试信息和对语言标准的遵循程度.  



# OI卡常模版1  
```

#define OI 0
#if defined(__GCC__) && (OI)
#pragma GCC push_options

#pragma GCC optimize(2)
#pragma GCC optimize(3)
#pragma GCC optimize("Ofast")
#pragma GCC optimize("inline")
#pragma GCC optimize("-fgcse")
#pragma GCC optimize("-fgcse-lm")
#pragma GCC optimize("-fipa-sra")
#pragma GCC optimize("-ftree-pre")
#pragma GCC optimize("-ftree-vrp")
#pragma GCC optimize("-fpeephole2")
#pragma GCC optimize("-ffast-math")
#pragma GCC optimize("-fsched-spec")
#pragma GCC optimize("unroll-loops")
#pragma GCC optimize("-falign-jumps")
#pragma GCC optimize("-falign-loops")
#pragma GCC optimize("-falign-labels")
#pragma GCC optimize("-fdevirtualize")
#pragma GCC optimize("-fcaller-saves")
#pragma GCC optimize("-fcrossjumping")
#pragma GCC optimize("-fthread-jumps")
#pragma GCC optimize("-funroll-loops")
#pragma GCC optimize("-fwhole-program")
#pragma GCC optimize("-freorder-blocks")
#pragma GCC optimize("-fschedule-insns")
#pragma GCC optimize("inline-functions")
#pragma GCC optimize("-ftree-tail-merge")
#pragma GCC optimize("-fschedule-insns2")
#pragma GCC optimize("-fstrict-aliasing")
#pragma GCC optimize("-fstrict-overflow")
#pragma GCC optimize("-falign-functions")
#pragma GCC optimize("-fcse-skip-blocks")
#pragma GCC optimize("-fcse-follow-jumps")
#pragma GCC optimize("-fsched-interblock")
#pragma GCC optimize("-fpartial-inlining")
#pragma GCC optimize("no-stack-protector")
#pragma GCC optimize("-freorder-functions")
#pragma GCC optimize("-findirect-inlining")
#pragma GCC optimize("-fhoist-adjacent-loads")
#pragma GCC optimize("-frerun-cse-after-loop")
#pragma GCC optimize("inline-small-functions")
#pragma GCC optimize("-finline-small-functions")
#pragma GCC optimize("-ftree-switch-conversion")
#pragma GCC optimize("-foptimize-sibling-calls")
#pragma GCC optimize("-fexpensive-optimizations")
#pragma GCC optimize("-funsafe-loop-optimizations")
#pragma GCC optimize("inline-functions-called-once")
#pragma GCC optimize("-fdelete-null-pointer-checks")

#pragma GCC target("avx", "sse2")

#endif

// benchmark code  
//...



#if defined(__GCC__) && (OI)
#pragma GCC pop_options
#endif


```

# 卡常模版2
```

```