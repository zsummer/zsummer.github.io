---
title: 类型擦除
date: 2019-01-17 11:21:00
categories: develop 
author: yawei.zhang 
---

### 类型擦除定义  

** 不需要程序伴随类型修饰的操作语义成为擦除语义, 用来使程序在运行时不依赖类型.  **  

### 类型擦除语义或者可实现类型擦除效果的实现方式   
* 多态    
* 闭包   
* 模板 (可以在C++模板中应用鸭子风格)   
* 容器 any/tuploe     

  <!-- more --> 
### 扩展 JAVA的泛型实现方式 类型擦除  
```
List<String> l1 = new ArrayList<String>();
List<Integer> l2 = new ArrayList<Integer>();

System.out.println(l1.getClass() == l2.getClass());
```
> 输出为true  

** 泛型信息只存在于代码编译阶段，在进入 JVM 之前，与泛型相关的信息会被擦除掉，专业术语叫做类型擦除。 **  

** 泛型转译 **   

```
public class Erasure <T>
{
    T object;
    public Erasure(T object) 
    {
        this.object = object;
    }
}
```

> Erasure 是一个泛型类，我们查看它在运行时的状态信息可以通过反射。  
```
Erasure<String> erasure = new Erasure<String>("hello");
Class eclz = erasure.getClass();
System.out.println("erasure class is:"+eclz.getName());
```
> 打印的结果是  
```
erasure class is:com.frank.test.Erasure  
```

> 泛型类被类型擦除后，相应的类型就被替换成 Object 类型呢？  
在泛型类被类型擦除的时候，之前泛型类中的类型参数部分如果没有指定上限，如 <T> 则会被转译成普通的 Object 类型，如果指定了上限如 <T extends String> 则类型参数就被替换成类型上限。   


    类型擦除，是泛型能够与之前的 java 版本代码兼容共存的原因。但也因为类型擦除，它会抹掉很多继承相关的特性，这是它带来的局限性。

理解类型擦除有利于我们绕过开发当中可能遇到的雷区，同样理解类型擦除也能让我们绕过泛型本身的一些限制。
```
public class ToolTest 
{
    public static void main(String[] args) 
    {
        List<Integer> ls = new ArrayList<>();
        ls.add(23);
//      ls.add("text");
        Method method = ls.getClass().getDeclaredMethod("add",Object.class);
        method.invoke(ls,"test");
        method.invoke(ls,42.9f);
    }
}
```


