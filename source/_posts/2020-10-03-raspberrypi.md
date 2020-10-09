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

<!--more-->

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






## wifi 5G时区问题   
可能导致找不到wifi信号或者连上去后很快断开   

修改/etc/config/system
```
config system
        option timezone 'CST-8'
        option zonename 'Asia/Shanghai'
```
修改/etc/config/wireless
```
        option country 'CN'
```

中国开放的5G频道为
36, 40, 44, 48, 52, 56, 60, 64, 149,153, 157, 161, 165  

opkg安装iw  iwinfo命令  

通过```iwinfo wlan0 ***``` 可以查看无线网卡的当前信息 以及支持的信号强度  模式等   

例如通过```iwinfo wlan0 htmodelist```可以查看支持的htmode  
例如通过```iwinfo wlan0 freqlist```可以查看支持的频段  

通过iw list查看设备支持的工作模式 
iw wlan0 info
iw phy0 info

iw reg get 获取频段和信道宽度
### 补充信息 
https://openwrt.org/docs/guide-user/network/wifi/basic#htmodethe_wi-fi_channel_width   

HT20 High Throughput 20MHz, 802.11n
HT40 High Throughput 40MHz, 802.11n
HT40- High Throughput 40MHz, 802.11n, control channel is bellow extension channel.
HT40+ High Throughput 40MHz, 802.11n, control channel is above extension channel.
VHT20 Very High Throughput 20MHz, Supported by 802.11ac
VHT40 Very High Throughput 40MHz, Supported by 802.11ac
VHT80 Very High Throughput 80MHz, Supported by 802.11ac
VHT160 Very High Throughput 160MHz, Supported by 802.11ac
NOHT disables 11n

可能得组合 

```
config	wifi-device		'radio0'
	option	channel		'104'
	option	hwmode		'11a'
	option	htmode		'HT20'
```

```
config	wifi-device		'radio0'
	option	channel		'7'
	option	hwmode		'11ng'
	option	htmode		'HT40+'
```

```
config	wifi-device		'radio0'
	option	channel		'36'
	option	hwmode		'11na'
	option	htmode		'HT40+'
```



### 快照版本问题  
如果安装的是快照版本 会有以下几个问题:  
1. 没有luci   需要手动安装   
2. 快照版本为自动构建且软件源对应自动构建的构建版号  导致一旦下个快照产生(通常几个小时?)就会导致软件源无法正常使用    

快照版本的好处是可以刷完TF卡后直接启动而不需要任何引导步骤(通常至少需要一个USB键盘和HDMI+显示器)   


