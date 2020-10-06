---
title: 树莓派使用
date: 2020-10-03
categories: develop 
author: yawei.zhang 
mathjax: false
---

## 树莓派官方地址和镜像下载  
[官方地址https://openwrt.org/](https://openwrt.org/zh/)    
[根据硬件下载](https://openwrt.org/toh/views/toh_fwdownload?dataflt%5B0%5D=supported%20current%20rel_%3D19.07.4)   
例如树莓派的分支可以再Brand分支中查找关键字**Raspberry Pi**   

快速上手推荐直接安装镜像 即跳过系统安装部分直接启动就可以使用, 带来的问题是 一般我们使用的tf卡可能至少32G 但是烧录的镜像只能用到其中的几百M 需要利用工具进行额外的mount挂载.    

这里有几个关键字 factory指的的是安装固件  sysupgrade是指的更新专用镜像文件   snapshots是快照镜像文件   

例如树莓派3B对应的最新版本[view data](https://openwrt.org/toh/hwdata/raspberry_pi_foundation/raspberry_pi_3_b)如下:  

```
Device Type:Single Board ComputerBrand:Raspberry Pi FoundationModel:Raspberry Pi 3Version:B
Supported Current Rel:19.07.4Unsupported Functions:Country Code settingGluon support:unknownTarget:bcm27xxSubtarget:bcm2710Package architecture:aarch64_cortex-a53
Device Page:raspberry_piForum search:Raspberry Pi 3Git search:Raspberry Pi 3WikiDevi URL:https://wikidevi.wi-cat.ru/RPF_Raspberry_Pi_3_Model_BWikiDevi ID:RPF_Raspberry_Pi_3_Model_BOEM Device Homepage URL:https://www.raspberrypi.org/products/raspberry-pi-3-model-b/Firmware OEM Stock URL:https://www.raspberrypi.org/downloads/Firmware OpenWrt Install URL:http://downloads.openwrt.org/releases/19.07.4/targets/brcm2708/bcm2710/openwrt-19.07.4-brcm2708-bcm2710-rpi-3-ext4-factory.img.gzFirmware OpenWrt Upgrade URL:http://downloads.openwrt.org/releases/19.07.4/targets/brcm2708/bcm2710/openwrt-19.07.4-brcm2708-bcm2710-rpi-3-ext4-sysupgrade.img.gzFirmware OpenWrt snapshot Install URL:http://downloads.openwrt.org/snapshots/targets/bcm27xx/bcm2710/openwrt-bcm27xx-bcm2710-rpi-3-ext4-factory.img.gzFirmware OpenWrt snapshot Upgrade URL:http://downloads.openwrt.org/snapshots/targets/bcm27xx/bcm2710/openwrt-bcm27xx-bcm2710-rpi-3-ext4-sysupgrade.img.gzInstallation method(s):SD card, see devicepage
```




## 下载镜像文件并烧录到tf卡   
[win32diskimager](https://win32diskimager.download/)   
把下载的镜像通过这个工具烧录到tf卡中   
这里唯一要注意的是如果有多个U盘设备 要正确选择好  

## 启动树莓派   

1. 插入tf卡  把电脑的网线插入树莓派的网线口(装好openwrt的树莓派相当于一个路由器)   
2. 插电  等待与20-30秒  
3. 正常情况下电脑会被分配一个**192.168.1.X**的IP地址 此时树莓派的网络地址是192.168.1.1 如果没成功检查是否存在网络IP段的冲突问题或者本级的DHCP等网络问题  
4. 默认的ssh地址是root@192.168.1.1 端口是22  没有密码   


## 让树莓派连接外网  
树莓派有一个集成的wifi和一个网络端口  默认情况下wifi的配置是ap热点并且处于关闭(系统第一次启动不插网线应该是打开状态)   
因此要想让树莓派能连外网并且可以连ssh  至少有一个网卡连我们的电脑 另外一个网卡连外网路由器   
这里使用的方法是先通过网线连接树莓派 然后开启wireless并且设置为sta客户端模式连外网   

修改**/etc/config/network** 添加Wwan    
```
config interface 'Wwan'
        option proto 'dhcp'
```

修改后如下:  
```
config interface 'loopback'
        option ifname 'lo'
        option proto 'static'
        option ipaddr '127.0.0.1'
        option netmask '255.0.0.0'

config globals 'globals'
        option ula_prefix 'fdd5:579e:a386::/48'

config interface 'lan'
        option type 'bridge'
        option ifname 'eth0'
        option proto 'static'
        option ipaddr '192.168.1.1'
        option netmask '255.255.255.0'
        option ip6assign '60'
config interface 'Wwan'
        option proto 'dhcp'
```

修改**/etc/config/wireless**  
默认为AP热点:
```
config wifi-device 'radio0'
        option type 'mac80211'
        option channel '11'
        option hwmode '11g'
        option path 'platform/soc/3f300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1'
        option htmode 'HT20'
        option disabled '0'

config wifi-iface 'default_radio0'
        option device 'radio0'
        option network 'lan'
        option mode 'ap'
        option ssid 'OpenWrt'
        option encryption 'none'
```
修改为STA连接我们的wifi
```
config wifi-device 'radio0'
        option type 'mac80211'
        option channel '11'
        option hwmode '11g'
        option path 'platform/soc/3f300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1'
        option htmode 'HT20'
        option disabled '0'

config wifi-iface 'default_radio0'
        option device 'radio0'
        option network 'Wwan'
        option mode 'sta'
        option ssid 'SUMMER'
        option encryption 'psk2'
        option key '1234512345'
```
执行**/etc/init.d/network restart**重启网络服务  

通过路由器的管理页面此时应当发现连接上了路由器  
如果这一步存在问题 可以先设置disable '0'在不该AP mod类型的情况下看看作为ap热点模式是否能正常搜索到   
ssh登录后尝试ping一下看看是否能正常连网   

## 让树莓派作为软路由 
和上面不同 这个是用网线连接外网 ap热点保留 
先用网线连接树莓派 修改wireless的disable为0 重启网络服务

需要重启树莓派  
network  
```

config interface 'lan'
        option ifname 'wlan0'
        option proto 'static'
        option ipaddr '192.168.1.1'
        option netmask '255.255.255.0'
        option ip6assign '60'

config interface 'wan'
        option ifname 'eth0'
        option proto 'dhcp'
```

wireless  
```
config wifi-device 'radio0'
        option type 'mac80211'
        option channel '11'
        option hwmode '11g'
        option path 'platform/soc/3f300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1'
        option htmode 'HT20'
        option disabled '0'

config wifi-iface 'default_radio0'
        option device 'radio0'
        option network 'lan'
        option mode 'ap'
        option ssid 'SUMMER_RPI'
        option encryption 'psk2'
        option key 'aaaaaaaaaa'
```



## 更新opkg     
```
opkg update
```
此时可以通过opkg list查看所有支持的包 
手动安装可以opkg install 命令   
这里推荐先安装luci web管理服务   

## 安装luci包和fdisk包    
```
pokg install luci  
opkg install luci-theme-bootstrap  
```
进入后台页面[http://192.168.1.1/](http://192.168.1.1/)   
账号root  密码空  
设置主题为bootstrap  

```
opkg install fdisk
```
安装完毕此时应该改还剩余80M空间   
可以通过```df -h```命令查看  

## 挂载剩余tf卡空间  
通过命令```fdisk -l```查看当前TF卡的挂载情况  
对空闲硬盘进行分区
```
fdisk /dev/mmcblk0
```

## 安装kcp  
```
opkg install kcptun-client
```
编辑/etc/config/kcptun 进行配置  
删除多余参数,修改关键option, 注意启用  
```
config client
        option disabled 0
        option bind_address '0.0.0.0'
        option local_port 12948
        option server '4.2.4.73'
        option server_port 18224 
        option mode 'fast2'
```

## 安装ss
使用luci后台或者opkg安装:  
```
opkg install shadowsocks-libev-ss-local shadowsocks-libev-ss-rules shadowsocks-libev-ss-redir shadowsocks-libev-ss-tunnel shadowsocks-libev-config iptables-mod-conntrack-extra luci-app-shadowsocks-libev
```
shadowsocks-libev-ss-local
shadowsocks-libev-ss-rules
shadowsocks-libev-ss-redir
shadowsocks-libev-ss-tunnel
shadowsocks-libev-config
iptables-mod-conntrack-extra
luci-app-shadowsocks-libev

1. 在luci后台的Service下面的Shadowsocks下填写remote server信息为本地kcp监听端口   
2. 在local instances下启用ss local  端口1080  (点击disable按钮)

此时启动了一个1080的ss端口连接服务器  (socks5端口)

点击Save&Apply进行保存  

然后在本地电脑上使用chrome+switchyOmega新建一个socks5代理连接youtube进行测试 .   



## 透明代理转发  
启用Local Instances ss_redir.hi  启用Redir Rules并更改Local-out default为forward   


可能问题 
检查IP转发
cat /proc/sys/net/ipv4/ip_forward
若为0
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p


可能问题 DNS污染  
需要开启resole固定 
以及转发 
https://wangchujiang.com/linux-command/c/iptables.html
https://gist.github.com/wen-long/8644243















```
root@OpenWrt:~# fdisk /dev/mmcblk0

Welcome to fdisk (util-linux 2.36).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.


Command (m for help): p
```

```
wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.25.2.tar.gz
tar -xvf git-2.25.2.tar.gz
cd git-2.25.2
make configure NO_OPENSSL=1
./configure --prefix=/usr/local/git  all
make 
make install
echo "export PATH=/usr/local/git/bin:$PATH" >> /etc/profile
source /etc/profile
```
<!-- more -->

### 编译git-lfs
```
go build
go install
```

### 手动下载安装包
```
tar xf git-lfs-*.tar.gz
cd git-lfs-*
sudo ./install.sh
```

### 存放到git bin目录后执行
```
git lfs install
```


### 使用git-lfs

添加跟踪
```
git lfs track "*.so"
git lfs track "resource/*"
```



一定要先track然后再进行add commit操作  

其他命令
```
# 查看当前使用 Git LFS 管理的匹配列表
git lfs track

# 使用 Git LFS 管理指定的文件
git lfs track "*.psd"

# 不再使用 Git LFS 管理指定的文件
git lfs untrack "*.psd"

# 类似 `git status`，查看当前 Git LFS 对象的状态
git lfs status

# 枚举目前所有被 Git LFS 管理的具体文件
git lfs ls-files

# 检查当前所用 Git LFS 的版本
git lfs version

# 针对使用了 LFS 的仓库进行了特别优化的 clone 命令，显著提升获取
# LFS 对象的速度，接受和 `git clone` 一样的参数。 [1] [2]
git lfs clone https://github.com/user/repo.git
```


