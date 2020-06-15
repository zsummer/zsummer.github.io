---
title: shadowsocks代理远端和本地配置以及VPS上的bbr开启等
date: 2020-05-09
categories: develop 
author: yawei.zhang 
---

## shadowsocks服务器配置  
* 安装shadowsocks  
```
apt-get install shadowsocks
```
* 配置shadowsocks
  配置路径
  ```
  /etc/shadowsocks/config.json
  ```
* 配置内容(参考):
  ```
  {
    "server":["::1", "0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":8080,
    "password":"****",
    "method":"aes-256-cfb"
  }
  ```
  <!-- more -->  
  
* 参数说明:
  |-|-|
  |名称|解释|
  |-|-|
  |server|    服务端监听地址| 
  |server_port |服务端端口| 
  |local_address|本地监听地址| 
  |local_port|本地端口| 
  |password|用于加密的密码| 
  |timeout|超时时间（秒）| 
  |method|加密方式，默认为 chacha20-ietf-poly1305| 
  |mode|是否启用 TCP / UDP 转发，参阅 shadowsocks-libev(8)| 
  |fast_open|是否启用 TCP Fast Open| 
  |workers|worker 数量| 
* 参数内容/详细  
  shadowsocks执行 
  ```
  ssserver -h
  ```
  shadowsocks-libev执行
  ```
  ss-server -h
  ```

* 停止/开启/重启服务
  ```
  /etc/init.d/shadowsocks restart
  ```


## kcptun加速 
* 下载/安装kcptun  
  在比较新的linux系统中默认已经有kcptun的源 例如debian10中可以用以下命令直接安装  
  ``` Shell
    apt-get install kcptun
  ```

* 示例启动脚本
  开启kcptun进行加速, 如下命令使用 fast2 和fast3模式打开两个通道  其中从8081接受到的数据会以mode fast2转发到本地的8080端口     
  ```
  killall server_linux_amd64 -w
  /root/.ssh/server_linux_amd64 -t "127.0.0.1:8080" -l ":8081" -mode fast2  1>/dev/null 2>&1 &
  /root/.ssh/server_linux_amd64 -t "127.0.0.1:8080" -l ":8082" -mode fast3  1>/dev/null 2>&1 &
  ```

* shadowsocks 客户端配置   
  支持插件启动的shadowsocks 在插件选项中填写 kcptun  
  在插件的选项中填写, 这里要注意有的版本 插件选项一栏要留空格 否则会出现黏连问题导致配置错误    
  ```
   -mode fast2
  ```
  如果没有内置kcptun 则需要下载kcptun到shadowsocks的目录下, 这时插件的名字则为可执行程序的名称  

* kcptun-client 
  ```
  kcptun-client -l":8081" -r"vps:8081" --mode fast2 1>/dev/null 2>&1 &  
  ```

## linux本地配置
* 下载shadowsocks   

* 填写配置到某文件例如 example.json  如下:  
  ```
  {                                                                                                                                                               
    "server":"remote ip",
    "server_port":remote port,
    "local_address":"127.0.0.1",
    "local_port":8080,
    "password":"****",
    "method":"aes-256-cfb"
  }
  ```

* 然后以以下命令进行启动   
  ```
  sslocal -c example.json -d start  
  ```
  如果是shadowsocks-libev  上述命令由sslocal改为ss-local即可   

* 通过kcptun启动本地shadowsocks  
  脚本如下:  
  ```
  killall sslocal
  killall kcptun-client
  kcptun-client  -r "remote:9090" -l ":8081" -mode fast2  &
  sslocal -s 127.0.0.1 -p 8024 -l 8081 -k passwd -m aes-256-cfb  -d start 
  ```

* 测试代理命令   --socks5-hostname 和--socks5的区别在于前者的dns解析是在远端进行 后者在本地  
  ```
  curl --socks5 127.0.0.1:8080 www.youtube.com
  ```

## linux本地的proxy设置转换和使用   
  大部分命令是没有--socks5这样的选项以供使用的   常用的代理转换工具如下:   
* 安装privoxy服务  

* 配置/etc/privoxy/config  
  ```
  forward-socks5t   /               127.0.0.1:9050 .
  listen-address  127.0.0.1:1080
  listen-address  [::1]:1080
  ```

  通过这样的配置可以提供本地http代理1080, 并把所有请求fowrad到socks5的目标127.0.0.1:9050   
  通过针对域名/IP的规则匹配, 可以实现把不同的请求转发到不同的目标服务器上 例如对于本地请求可以进行跳过:  
  ```
  forward         192.168.*.*/     .
  ```

* 设置linux代理  
  编辑/etc/bash.bashrc 或者```~/.bashrc ```     
  ```
  export http_proxy="http://127.0.0.1:1080"
  export https_proxy="http://127.0.0.1:1080"
  ```


## linux本地的proxy方案proxychains  
这个命令比上述的linux本地方案更方便一些   
* 安装proxychains

* 编辑proxychains的配置文件  /etc/proxychains.conf   
  ```
  [ProxyList]
  socks5  127.0.0.1 8080
  ```

* 使用和测试  在进行任何需要代理的命令前面增加proxychains即可  例如:
  ```
  proxychains wget youtube.com
  ```

## 网络调优/开启BBR   

* 查看os版本 4.9之后系统支持bbr
  ```
  uname -a
  ```

* 查看是否开启bbr  
  ```
  lsmod | grep bbr
  ```

* 更新内核到4.9: Debian 8 / Ubuntu 14 / Ubuntu 16
  ```
  wget -c http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.11.4/linux-image-4.11.4-041104-generic_4.11.4-041104.201706071003_amd64.deb
  ```

* 更新内核  
  ```
  dpkg -i linux-image-4.*.deb
  ```

* 清理旧内核(可跳过)
  ```
  apt-get autoremove
  ```

* 更新 grub 系统引导文件并重启  
  ```
  update-grub
  reboot
  ```

* 开启BBR算法   
  ```
  modprobe tcp_bbr
  echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p
  ```

* 测试应该均有bbr  
  ```
  sysctl net.ipv4.tcp_available_congestion_control
  sysctl net.ipv4.tcp_congestion_control
  ```
  

* 最新的发行版现在默认都已开启BBR   