---
title: 位置无关代码    
date: 2019-11-09
categories: develop 
author: yawei.zhang 
---
### ELF文件   
###### 内存布局  

| LINKING VIEW 
| -
| ELF HEADER
| PROGRAM HEADER TABLE OPTIONAL 
| SECTION 1  
| SECTION 2
| SECTION n ...
| SECTION HEADER TABLE  

###### 执行视图  
| EXECUTION VIEW 
| - 
| PROGRAM HEADER TABLE 
| SEGMENT 1 
| SEGMENT 2 
| SEGMENT N ...
| SECTION HEADER TABLE OPTIONAL 

###### 主要区别    
* PROGRAM HEADER TABLE是运行时对应SEGMENT的TABLE 所以在目标文件中并不需要存在 实际上GCC代码编译出来的目标文件也不存在该
* 节 SECTION  (目标文件中的SECTION是和SECTION HEADER TABLE中的条目一一对应, 用于链接器对代码进行重定位(非PIC会重定位))
  * .TEXT
  * .BSS
  * .DATA  
  
* 分段  SEGMENT (载入内存后以SEGMENT组织, SEGMENT对应PROGRAM HEADER TABLE 中的条目, 目标代码中的SECTION会组织到各个SEGMENT中)  
  * .TEXT的内容会组织到代码段中  
  * .DATA .BSS的内容会包含在数据段中  

<!-- more --> 


### 分析过程   
 通过命令 readelf a.out -S section 查看SECTION 可以看到.plt .plt.got的信息  
 旗标FLAG中 A代表分配内存  X代表执行 W为可写  见末尾KEY说明  
 ```
 文件：a.out
共有 36 个节头，从偏移量 0x2c00 开始：

节头：
  [号] 名称              类型             地址              偏移量              大小              全体大小        旗标   链接   信息   对齐
  [ 0]                   NULL             0000000000000000  00000000       0000000000000000  0000000000000000           0     0     0
  [ 1] .interp           PROGBITS         0000000000000238  00000238       000000000000001c  0000000000000000   A       0     0     1
  [ 2] .note.ABI-tag     NOTE             0000000000000254  00000254       0000000000000020  0000000000000000   A       0     0     4
  [ 3] .note.gnu.build-i NOTE             0000000000000274  00000274       0000000000000024  0000000000000000   A       0     0     4
  [ 4] .gnu.hash         GNU_HASH         0000000000000298  00000298       000000000000001c  0000000000000000   A       5     0     8
  [ 5] .dynsym           DYNSYM           00000000000002b8  000002b8       00000000000000f0  0000000000000018   A       6     1     8
  [ 6] .dynstr           STRTAB           00000000000003a8  000003a8       00000000000000c9  0000000000000000   A       0     0     1
  [ 7] .gnu.version      VERSYM           0000000000000472  00000472       0000000000000014  0000000000000002   A       5     0     2
  [ 8] .gnu.version_r    VERNEED          0000000000000488  00000488       0000000000000020  0000000000000000   A       6     1     8
  [ 9] .rela.dyn         RELA             00000000000004a8  000004a8       00000000000000d8  0000000000000018   A       5     0     8
  [10] .rela.plt         RELA             0000000000000580  00000580       0000000000000048  0000000000000018  AI       5    24     8
  [11] .init             PROGBITS         00000000000005c8  000005c8       0000000000000017  0000000000000000  AX       0     0     4
  [12] .plt              PROGBITS         00000000000005e0  000005e0       0000000000000040  0000000000000010  AX       0     0     16
  [13] .plt.got          PROGBITS         0000000000000620  00000620       0000000000000008  0000000000000000  AX       0     0     8
  [14] .text             PROGBITS         0000000000000630  00000630       0000000000000212  0000000000000000  AX       0     0     16
  [15] .fini             PROGBITS         0000000000000844  00000844       0000000000000009  0000000000000000  AX       0     0     4
  [16] .rodata           PROGBITS         0000000000000850  00000850       0000000000000027  0000000000000000   A       0     0     4
  [17] .eh_frame_hdr     PROGBITS         0000000000000878  00000878       000000000000003c  0000000000000000   A       0     0     4
  [18] .eh_frame         PROGBITS         00000000000008b8  000008b8       000000000000010c  0000000000000000   A       0     0     8
  [19] .init_array       INIT_ARRAY       0000000000200da8  00000da8       0000000000000008  0000000000000008  WA       0     0     8
  [20] .fini_array       FINI_ARRAY       0000000000200db0  00000db0       0000000000000008  0000000000000008  WA       0     0     8
  [21] .jcr              PROGBITS         0000000000200db8  00000db8       0000000000000008  0000000000000000  WA       0     0     8
  [22] .dynamic          DYNAMIC          0000000000200dc0  00000dc0       0000000000000210  0000000000000010  WA       6     0     8
  [23] .got              PROGBITS         0000000000200fd0  00000fd0       0000000000000030  0000000000000008  WA       0     0     8
  [24] .got.plt          PROGBITS         0000000000201000  00001000       0000000000000030  0000000000000008  WA       0     0     8
  [25] .data             PROGBITS         0000000000201030  00001030       0000000000000010  0000000000000000  WA       0     0     8
  [26] .bss              NOBITS           0000000000201040  00001040       0000000000000008  0000000000000000  WA       0     0     1
  [27] .comment          PROGBITS         0000000000000000  00001040       000000000000002d  0000000000000001  MS       0     0     1
  [28] .debug_aranges    PROGBITS         0000000000000000  0000106d       0000000000000030  0000000000000000           0     0     1
  [29] .debug_info       PROGBITS         0000000000000000  0000109d       0000000000000973  0000000000000000           0     0     1
  [30] .debug_abbrev     PROGBITS         0000000000000000  00001a10       0000000000000211  0000000000000000           0     0     1
  [31] .debug_line       PROGBITS         0000000000000000  00001c21       0000000000000155  0000000000000000           0     0     1
  [32] .debug_str        PROGBITS         0000000000000000  00001d76       00000000000003d7  0000000000000001  MS       0     0     1
  [33] .symtab           SYMTAB           0000000000000000  00002150       0000000000000708  0000000000000018          34    52     8
  [34] .strtab           STRTAB           0000000000000000  00002858       0000000000000256  0000000000000000           0     0     1
  [35] .shstrtab         STRTAB           0000000000000000  00002aae       000000000000014c  0000000000000000           0     0     1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  l (large), p (processor specific)
 ```



 https://www.cnblogs.com/jiqingwu/p/elf_format_research_01.html
 https://blog.csdn.net/qq_32400847/article/details/71001693
 http://www.wowotech.net/basic_subject/pic.html
 https://blog.csdn.net/loushuai/article/details/50493603