
---
title: 睡眠质量Checklist (个体经验值)  
date: 2024-04-01
categories: develop 
author: yawei.zhang 
mathjax: false
---

* 入睡时的咖啡因代谢剩余应当低于20mg    
     * 咖啡因的代谢半衰期约为6.  
     * 50mg的红牛在中午12点摄入, 那么在晚上12点后剩余约为12.5mg
     * 150mg的咖啡在中午12点摄入, 那么在晚上12点后剩余约为37.5, 即使能入睡也会影响到睡眠  
     * 低因咖啡的含量约为10~20mg   
* 入睡前4个小时内不能有剧烈活动, 力量训练 短跑等.  

* 入睡前3个小时内不能喝蛋白粉, 或者暴食,  敏感状态下禁食.   

* 入睡环境噪声影响 敏感情况下塞水晶泥  
* 入睡环境应当黑暗 敏感情况下带上眼罩  
     * 避免早上的天光提前唤醒  
     * 提高入睡环境   
     * 避免起夜时太强的灯光  
     * 避免拿起手机导致重新CD   


* TODO: list  
     * 当因为睡前复盘想起来某些关键事情导致自己无法安心入睡时  
          * 立刻订好明天早上的日程并写清楚todo 内容.  
          * 写在便签并贴在自己醒来后一定能看到的地方
          * 原则上不要让大脑挂太多to list   
          * 原则上睡眠状态的大脑无法很好的处理重要事情 并导致白天的活动受影响从而形成恶性循环   

* 仍然失眠  
     * 不要睁开眼 让海马体处理完隐藏任务后 大脑仍然会有一定的休息恢复   
     * 人生偶尔失眠错过或者导致没处理好一些重要的会议或者活动 从人类命运角度来看 也没那么值得焦虑  可以失眠并等待困的时候休息.  
       



```
ssh-keygen   

-f 指定文件名 默认为id_rsa
-t 指定类型 默认为rsa
-C 指定注释 默认无
```

<!--more -->

### 目标设备   
将public key 附加到目标设备的目标用户的home目录下的文件  ```.ssh/authorized_keys``` 中   如果没有则创建  权限应为640


### 跳板机设备   
当前用户下
 create a ~/.ssh/config file
```
Host tabs
     HostName tabs.com
     User     me
     IdentityFile       ~/.ssh/new_rsa

Host scm.company.com
     User       cap
     IdentityFile       ~/.ssh/git_rsa

Host project-staging
     HostName 50.56.101.167
     User     me
     IdentityFile       ~/.ssh/new_rsa
```

like
```
Host 99.99.88.99
        User ssssummmmerrr
        IdentityFile ~/.ssh/keys/udp
```
