---
title: AS-A 和 HAS-A 概念  
date: 2019-11-29
categories: develop 
author: yawei.zhang 
---

### 目录  

---  

<!-- TOC -->

- [目录](#目录)
- [词的关系概括](#词的关系概括)
    - [polysemy 词汇蕴含规则](#polysemy-词汇蕴含规则)
        - [linear polysemy 线性多义](#linear-polysemy-线性多义)
        - [non-linear polysemy 非线性多义](#non-linear-polysemy-非线性多义)
        - [一词多义](#一词多义)
    - [hyperonym–hyponym 上下义关系](#hyperonymhyponym-上下义关系)
    - [autonymy 反义关系](#autonymy-反义关系)
    - [synonymy 同义关系](#synonymy-同义关系)
- [语义聚合关系](#语义聚合关系)
    - [上下义词](#上下义词)
    - [总分词](#总分词)
    - [类义词(狭义)](#类义词狭义)
- [面向对象中的关系](#面向对象中的关系)
    - [类型和实例关系](#类型和实例关系)
    - [hyperonym–hyponym (supertype–subtype) 上下义关系, 超类子类关系  IS-A 关系 继承/泛化关系](#hyperonymhyponym-supertypesubtype-上下义关系-超类子类关系--is-a-关系-继承泛化关系)
    - [holonym–meronym  整体部分关系 HAS-A 关系](#holonymmeronym--整体部分关系-has-a-关系)
- [集合关系](#集合关系)

<!-- /TOC -->
### 词的关系概括  
#### polysemy 词汇蕴含规则     
##### linear polysemy 线性多义
* autohyponymy, where the basic sense leads to a specialised sense  基本意义->特殊意义  
* automeronymy, where the basic sense leads to a subpart sense 基本意义->部分意义  整体->局部  
* autohyperonymy or autosuperordination, where the basic sense leads to a wider sense   基本意义->宽泛意义  下位->上位意义  
* autoholonymy, where the basic sense leads to a larger sense  基本意义->更多意义 
##### non-linear polysemy 非线性多义  
* metonymy  转喻 借喻    
* metaphor 隐喻  
##### 一词多义    
* 原始意义与衍生意义(派生)   
* 普通意义与特殊意义  
* 抽象意义与具体意义  
* 字面意义与比喻意义  
#### hyperonym–hyponym 上下义关系  
#### autonymy 反义关系  
#### synonymy 同义关系 


### 语义聚合关系
#### 上下义词  
上下义关系代表了概念上的蕴含关系, 或者说在类型层级上, 下位类一定带有上位类的所有属性.  可以用 IS A 来表达.  

例如 上义词 水果  下义词 香蕉.  香蕉 IS A 水果  但是不能反过来说 水果 IS A  香蕉   

上下义关系也可以进入 'A包含B'的格式,  比如说香蕉包含水果的属性  

#### 总分词 
整体部分关系   用HAS A来表达  

例如 门  和  门套/门板    可以进入'A包含B'的格式 但是不能用  'B是A'的格式   

#### 类义词(狭义) 
多元关系中的同级词语  例如门下的 门套和门板的关系  




### 面向对象中的关系   
#### 类型和实例关系   
* Type–token distinction  例如一个语句中  rose is a rose 中有三个type 4个token   
  * type == classes  
  * object == instances ==token  
* type of    
  * (实例)的类型     
* instance of   
  * (类型) 的实例  

#### hyperonym–hyponym (supertype–subtype) 上下义关系, 超类子类关系  IS-A 关系 继承/泛化关系     
* 子类包含所有超类的属性/方法 可以用 "子类 IS A 父类" 来进行判定和使用   
* 所有可以对超类适用的规范同样也可以适用于其子类   
  * 李氏替换原则
    * Functions that use pointers or references to base classes must be able to use objects of derived classes without knowing it.  
    * 使用基类对象指针或引用的函数必须能够在不了解衍生类的条件下使用衍生类的对象   
    * 李氏替换原则中 避免重写父类的非抽象方法, 而多态的实现是通过重写抽象方法实现.   
    * 面向对象中的抽象方法是定义方法的声明规范而不约束其实现因此扔可 概括为上句 " 所有可以对超类适用的规范同样也可以适用于其子类"   

#### holonym–meronym  整体部分关系 HAS-A 关系  

*  aggregation 聚合关系  不存在所属权  HAS-A 关系  
   *  部分可以脱离/超出整体的生命周期独立存在 比如家庭成员和家庭  玩家和工会  
  
*  composition 组成关系  存在所属权  PART-OF| HAS-A 关系 
   * 部分不可以脱离整体的生命周期管理 比如四肢和人体  
   * 对于编程来讲, 我们实例化玩家对象, 实例化背包对象, 玩家下线需要连带清理背包对象.   
  
*  containment 包含关系   member-of | contains-a | part-of|HAS-A 关系  
   *  对成员的访问必须经过整体  成员为内涵状态  
   *  对于C++来说 privete:下的数据成员必须使用该类的接口访问  
   *  例如玩家对象和玩家的等级属性  




### 集合关系
从更抽象的角度来说
IS-A的关系判定为  A 是不是 B的特化 (specialization)
从集合关系来讲则为 A ⊃ B   A是不是B的真超集   


HAS-A的关系判定为 B 是不是 A的组成部分
从集合关系来讲则为 B ⊂ A         B 是不是A的的真子集   


ALIAS-A (没有这个术语) 的关系则是 A = B 即 别名.   


从集合角度来讲, 如果B是A的特化, 那么A同时也是B的构成,  即:
* B ⊃ A(IS-A) 可以推导出 A ⊂ B (HAS-A)  
* 但是IS-A限定了 A ⊂ B(HAS-A) 不可以推导出B ⊃ A (IS-A)     (IS-A限定特化后具有相同的拓扑结构)

因此

这IS-A这种关系 是 HAS-A 的特化.  即  IS-A  ⊃ HAS-A 

换成具体到OO语言里,  继承是一种特殊的聚合方式.
聚合更具有一般化的性质 更松散  

因此 IS-A  is a  HAS-A  通过IS-A到HAS-A的转化可获得更好的一般性(泛化)  泛化转关联本身也是一种泛化

