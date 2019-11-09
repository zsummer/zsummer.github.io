---
title: linux快速排查问题的命令  
date: 2019-11-05
categories: develop 
author: yawei.zhang 
---
### 全局分析和统计    
* top命令   
  * free 查看内存使用信息  
  * vmstate [delay时间]  按照delay时间打印内存使用 io读写 CPU用量等信息  
  * iostat -m -x [时间] [次数]   io读写详细信息

* sar 系统活动情况报告 追溯统计数据 从最近的0点0分开始显示数据   
  * sar -A 所有  
  * sar -u CPU  
  * sar -q 负载
  * sar -r 内存
  * CPU存在瓶颈，可用 sar -u 和 sar -q 等来查看
  * 内存存在瓶颈，可用sar -B、sar -r 和 sar -W 等来查看
  * I/O存在瓶颈，可用 sar -b、sar -u 和 sar -d 等来查看

* df 查看当前硬盘存储
  * du -h  --max-depth=1 [./]   统计当前目录树下的文件大小  

* IPC资源查询   
  * ipcs -m 查看共享内存资源  
  * ipcsrm -M [shmkey]  删除共享内存资源  
  * ipcsrm -m [shmid]    删除shmid标识的共享内存资源  

* ulimit -a   配置位置 /etc/security/limits.conf  
  * coredump文件的大小
  * 线程栈的大小  
  * 单进程最大设备数
    * 单进程最大设备数的硬性限制在/proc/sys/fs/nr_open 中配置  
    * 系统配置的最大设备数可查看/proc/sys/fs/file-max 中配置  
    * 系统配置的最大设备数修改/etc/sysctl.conf |  fs.file-max = 1000000

* 全局线程总数 
  * 查看位置 /proc/sys/kernel/threads-max  
  
* 单个进程最大线程数 PTHREAD_THREADS_MAX  新的NPTL实现中不存在该限制   
  * 查看位置 /usr/include/bits/local_lim.h 
  * 查看位置 /usr/include/x86_64-linux-gnu/bits/local_lim.h
  
* whereis   查看命令所在位置  

* lsof [文件/路径]  查看占用该文件/该目录下文件的进程  

* lsof -i  查看当前活动的网络连接 包括TCP / UDP

* lsof -p [pid] 查看当前进程所有打开的文件/设备

* ulimit -s 栈大小  

<!-- more --> 
### 进程分析和统计   

* pstack [pid]  查看进程栈  

* gstack [pid]  同pstack 可打印出每个线程的堆栈    

* gcore [pid1 pid2 ...]  dump core而不杀死进程   

* strace -T -r -c -p [pid] 查看或统计系统调用  -c统计.   
  
* strace [exe_file]  调试运行程序  统计或查看该程序所有系统调用    



* lsof [文件/路径]  查看占用该文件/该目录下文件的进程  

* lsof -i  查看当前活动的网络连接 包括TCP / UDP

* lsof -p [pid] 查看当前进程所有打开的文件/设备

* 内存布局的实际地址和实际大小等查询  内存泄露可快速判定
  * cat /proc/pid/maps 
  * pmap

### 系统   
uname -a  系统版本  
cat /proc/version  内核版本  
getconf GNU_LIBPTHREAD_VERSION   查看线程模型  

### 调试

* readelf  
  * 可重定位的对象文件(Relocatable file) .o文件   
  * 可执行的对象文件(Executable file)  
  * 可被共享的对象文件(Shared object file)  
  * readelf -a  [elf_file] 查看所有信息  
  * readelf -h  [elf_file] 查看概要信息
  * readelf -S  [elf_file] 查看所有段信息(比如-g编译会有debug段)  
  
* objdump  和readelf类似 但是可以反汇编elf文件  
  * objdump -S [file]  反汇编所有目标代码  
  
* size [file] 查看程序被映射到内存中映像的大小信息  



### 其他手册/详细手册   

###### ldd   查看程序运行时库  
显示 依赖的库名,  实际记载到的库, 库加载后的开始地址 


###### strace  
```
-c 统计每一系统调用的所执行的时间,次数和出错的次数等. 
-d 输出strace关于标准错误的调试信息. 
-f 跟踪由fork调用所产生的子进程. 
-ff 如果提供-o filename,则所有进程的跟踪结果输出到相应的filename.pid中,pid是各进程的进程号. 
-F 尝试跟踪vfork调用.在-f时,vfork不被跟踪. 
-h 输出简要的帮助信息. 
-i 输出系统调用的入口指针. 
-q 禁止输出关于脱离的消息. 
-r 打印出相对时间关于,,每一个系统调用. 
-t 在输出中的每一行前加上时间信息. 
-tt 在输出中的每一行前加上时间信息,微秒级. 
-ttt 微秒级输出,以秒了表示时间. 
-T 显示每一调用所耗的时间. 
-v 输出所有的系统调用.一些调用关于环境变量,状态,输入输出等调用由于使用频繁,默认不输出. 
-V 输出strace的版本信息. 
-x 以十六进制形式输出非标准字符串 
-xx 所有字符串以十六进制形式输出. 
-a column 
设置返回值的输出位置.默认 为40. 
-e expr 
指定一个表达式,用来控制如何跟踪.格式如下: 
[qualifier=][!]value1[,value2]... 
qualifier只能是 trace,abbrev,verbose,raw,signal,read,write其中之一.value是用来限定的符号或数字.默认的 qualifier是 trace.感叹号是否定符号.例如: 
-eopen等价于 -e trace=open,表示只跟踪open调用.而-etrace!=open表示跟踪除了open以外的其他调用.有两个特殊的符号 all 和 none. 
注意有些shell使用!来执行历史记录里的命令,所以要使用\\. 
-e trace=set 
只跟踪指定的系统 调用.例如:-e trace=open,close,rean,write表示只跟踪这四个系统调用.默认的为set=all. 
-e trace=file 
只跟踪有关文件操作的系统调用. 
-e trace=process 
只跟踪有关进程控制的系统调用. 
-e trace=network 
跟踪与网络有关的所有系统调用. 
-e strace=signal 
跟踪所有与系统信号有关的 系统调用 
-e trace=ipc 
跟踪所有与进程通讯有关的系统调用 
-e abbrev=set 
设定 strace输出的系统调用的结果集.-v 等与 abbrev=none.默认为abbrev=all. 
-e raw=set 
将指 定的系统调用的参数以十六进制显示. 
-e signal=set 
指定跟踪的系统信号.默认为all.如 signal=!SIGIO(或者signal=!io),表示不跟踪SIGIO信号. 
-e read=set 
输出从指定文件中读出 的数据.例如: 
-e read=3,5 
-e write=set 
输出写入到指定文件中的数据. 
-o filename 
将strace的输出写入文件filename 
-p pid 
跟踪指定的进程pid. 
-s strsize 
指定输出的字符串的最大长度.默认为32.文件名一直全部输出. 
-u username 
以username 的UID和GID执行被跟踪的命令
```


###### vmstat  
```
Procs（进程）:
  r: 运行队列中进程数量
  b: 等待IO的进程数量
Memory（内存）:
  swpd: 使用虚拟内存大小
  free: 可用内存大小
  buff: 用作缓冲的内存大小
  cache: 用作缓存的内存大小
Swap:
  si: 每秒从交换区写到内存的大小
  so: 每秒写入交换区的内存大小
  IO：（现在的Linux版本块的大小为1024bytes）
  bi: 每秒读取的块数
  bo: 每秒写入的块数
system：
  in: 每秒中断数，包括时钟中断
  cs: 每秒上下文切换数
  CPU（以百分比表示）
  us: 用户进程执行时间(user time)
  sy: 系统进程执行时间(system time)
  id: 空闲时间(包括IO等待时间)
  wa: 等待IO时间
```


###### sar   
```
-A 汇总所有的报告
-a 报告文件读写使用情况
-B 报告附加的缓存的使用情况
-b 报告缓存的使用情况
-c 报告系统调用的使用情况
-d 报告磁盘的使用情况
-g 报告串口的使用情况
-h 报告关于buffer使用的统计数据
-m 报告IPC消息队列和信号量的使用情况
-n 报告命名cache的使用情况
-p 报告调页活动的使用情况
-q 报告运行队列和交换队列的平均长度
-R 报告进程的活动情况
-r 报告没有使用的内存页面和硬盘块
-u 报告CPU的利用率
-v 报告进程、i节点、文件和锁表状态
-w 报告系统交换活动状况
-y 报告TTY设备活动状况
```


###### /proc/$pid/maps   虚拟内存地址  
```
address           perms offset  dev   inode   pathname
08048000-08056000 r-xp 00000000 03:0c 64593   /usr/sbin/gpm
```    
对应内核的vm_area_struct项  
* 地址 address [vm_start-vm_end]: 进程地址空间中区域的开始和结束地址  
  
* 权限 permissions [vm_flags]：虚拟内存的权限，
  * [r=读] [w=写] [x=执行]  [s/p=共享/私有]     
  * 禁用显示 - 
  * mprotect设置权限   
  
* 偏移量 offset [vm_pgoff]：映射开始的偏移量  
  * 对于有名映射, 比如从文件使用mmap的映射, 表示此段虚拟内存起始地址在文件中以页为单位的偏移 .  
    * 缺页异常时会根据这个找到文件对应地址的数据并加载上来  
  * 对匿名映射 它等于0或者vm_start/PAGE_SIZE   
  
* 设备 device：映像文件的主设备号和次设备号
  * 对匿名映射来说 因为没有文件在磁盘上 所以没有设备号 始终为00:00 
  * 对有名映射来说 是映射的文件所在设备的设备号   
* 节点 inode：映像文件的节点号
  * 对有名映射来说 是映射的文件的节点号
  * 对匿名映射来说 因为没有文件在磁盘上 所以没有节点号 始终为00:00  
* 路径 pathname: 映像文件的路径  
  * 对有名来说 是映射的文件名
  * 对匿名映射来说 是此段虚拟内存在进程中的角色 
    * [stack]表示在进程中作为栈使用 
    * [heap]表示堆
    * [vdso]表示虚拟动态共享对象 它被系统调用用于切换到内核模式   
    *  其余情况则无显示

###### pmap 虚拟内存地址  类似 /proc/$pid/maps   
显示的数据更干净一些  还能显示出比如共享内存的shmid和起始位置 和大小    


###### gstack  脚本  拷贝自centos  
```
#!/bin/sh

if test $# -ne 1; then
    echo "Usage: `basename $0 .sh` <process-id>" 1>&2
    exit 1
fi

if test ! -r /proc/$1; then
    echo "Process $1 not found." 1>&2
    exit 1
fi

# GDB doesn't allow "thread apply all bt" when the process isn't
# threaded; need to peek at the process to determine if that or the
# simpler "bt" should be used.

backtrace="bt"
if test -d /proc/$1/task ; then
    # Newer kernel; has a task/ directory.
    if test `/bin/ls /proc/$1/task | /usr/bin/wc -l` -gt 1 2>/dev/null ; then
        backtrace="thread apply all bt"
    fi
elif test -f /proc/$1/maps ; then
    # Older kernel; go by it loading libpthread.
    if /bin/grep -e libpthread /proc/$1/maps > /dev/null 2>&1 ; then
        backtrace="thread apply all bt"
    fi
fi

GDB=${GDB:-/usr/bin/gdb}

if $GDB -nx --quiet --batch --readnever > /dev/null 2>&1; then
    readnever=--readnever
else
    readnever=
fi

# Run GDB, strip out unwanted noise.
$GDB --quiet $readnever -nx /proc/$1/exe $1 <<EOF 2>&1 | 
set width 0
set height 0
set pagination no
$backtrace
EOF
/bin/sed -n \
    -e 's/^\((gdb) \)*//' \
    -e '/^#/p' \
    -e '/^Thread/p'
```
