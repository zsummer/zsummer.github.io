
---
title: ssh 设置根据用户和目标服务器地址自动匹配私钥登录  
date: 2024-01-18
categories: develop 
author: yawei.zhang 
mathjax: false
---


## 生成秘钥         
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
