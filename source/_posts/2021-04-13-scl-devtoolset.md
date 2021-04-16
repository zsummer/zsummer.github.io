
---
title: devtoolset
date: 2021-02-19
categories: develop 
author: yawei.zhang 
mathjax: false
---

## 安装环境
```
yum install epel-release centos-release-scl scl-utils scl-utils-build
```

## 查看完整列表(scl为源可更改)
```
yum --disablerepo="*" --enablerepo="scl" list available
```

## 搜索 安装  
```
yum --disablerepo="*" --enablerepo="scl" search ****
yum --disablerepo="*" --enablerepo="scl" install ****
yum --disablerepo="*" --enablerepo="scl" update ****
```


## 安装devtoolset  
```
yum --disablerepo="*" --enablerepo="*scl*" install devtoolset-10
```
```
yum --disablerepo="*" --enablerepo="scl" install devtoolset-10*
```

## 使用scl command   
```
scl enable python33 <command>
```

## 启用和切换 (当前会话有效)
```
scl enable devtoolset-8 bash
```
```
source /opt/rh/devtoolset-3/enable
```
```
scl enable python33 bash
```


## 查看已安装的SCL RPM 
```
scl --list
scl -l
```

## 安装多个gcc版本  
```
yum --enablerepo=tlinux-testing install devtoolset-9-gcc*
```

```
yum --enablerepo=tlinux-testing install devtoolset-7-gcc*
```
