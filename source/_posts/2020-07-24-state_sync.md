---
title: 多人游戏中的同步机制综述 
date: 2020-07-24
categories: develop 
author: yawei.zhang 
mathjax: true
---

<!-- toc -->


## 前言    
本文中所有内容默认都基于逻辑描述, 逻辑状态,逻辑处理的逻辑游戏世界,  纯本地表现类, 总是通过逻辑世界单向导出的渲染计算等, 均不在本篇文章讨论范畴.  


## 同步问题的产生和基本策略机制  

**在多人游戏或者基于CS网络模型的游戏中, 玩家所在的游戏世界并非全由本地生成和修改, 必须不断从服务器或者其他玩家获得最新的信息来完成游戏世界的共享体验, 在多人实时交互的游戏中,  相当于每个人都维护一个'完整世界'的副本, 并保证每个人维护的副本之间一致性和实时性, 不同游戏对副本的规模复杂度以及对一致性和实时性的要求不同, 并随着网络环境的变化在不同的历史时期下演化出了多种同步方案.**   

在所有的同步方案中, 有两种最基础也最常见的同步机制, 即状态同步和帧同步, 其基本机制和区别为:  

* **状态同步: 通过同步游戏中的各种状态来保证游戏世界副本的一致性, 基本流程如下:**   
  * 服务器维护权威完整副本  客户端维护本地副本 <font color=#ccc> (可以只维护部分副本) </font>   
  * 客户端上行请求到服务器 服务器进行完整的逻辑演算 并将发生改变的状态下行给客户端   
  * <font color=#ccc>客户端基于本地副本进行预演和状态预刷新 </font>  
  * 客户端用来自服务器的状态数据刷新本地副本, 对齐服务器副本   
    * <font color=#ccc>客户端如果有因预演导致的数据不对齐需要通过强同步/回滚/和解等机制达成最终对齐</font>   
      * <font color=#ccc>快照类同步方式总是全量对齐</font>   

  
* **帧同步: 泛指通过一致的初始状态, 一致的输入事件和一致的逻辑处理, 从而得到相同的计算结果来保证游戏世界副本的一致性的同步方案**    
  * 该术语为泛指, 所有通过确定性算法,以保证输入一致来得出相同游戏流程结果的同步均可泛称为帧同步.   
  * 最早有对等网络的锁步同步, 发展为非对等网络的主机锁步同步, 再到后来的bucket同步以及现在比较流行的定时不等待乐观帧同步  
  
  * 锁步同步:  
    * 客户端定时(比如每五帧为一个关键帧)上传一轮输入信息   
    * 服务器收到所有输入信息后广播给其他所有客户端  
    * 客户端用服务器发来的更新消息中的输入信息进行游戏(如果是对称网络, 这个过程则是广播自己输入信息和搜集所有其他客户端的输入信息)     
    * 如果客户端进行到下一个关键帧(5帧后)时没有收到服务器的更新消息则等待   
    * 如果客户端进行到下一个关键帧时已经接收到了服务器的更新消息, 则将上面的数据用于游戏, 并采集当前鼠标键盘输入发送给服务器, 同时继续进行下去   
    * 服务端采集到所有数据后再次发送下一个关键帧更新消息   
  
  * 定时不等待:     
    * 相对于锁步同步来说, 服务器会定时下发收集到的信息,  并根据收集到的信息调整关键帧的间隔,  没有在指定间隔内收到的消息会排在下一次关键帧或者丢弃   
    * 相对于锁步同步来说, 任何客户端的卡顿不会阻塞其他玩家   

**这两种同步模型本质上并不冲突, 并且在细节上会相互补充优化,  常见的为在状态同步这种弱一致性框架下添加确定性演算来增加同步的准确性, 在确定性的帧同步下隔离出来部分状态进行优化增加流畅性,  从模型角度来说, 在复杂的同步需求中, 状态同步总是比帧同步有更多的扩展和调优空间, 典型的案例如UE4和UNITY中的DS服务器.**   

<!-- more -->   

| .                          | 锁步同步                                                                                                            | 状态同步                                                                                                                                                                                                                         |
|----------------------------|---------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 流量                       | 一般情况下较低, 决定于网络玩家数目                                                                                  | 一般情况下较高, 决定于当前该客户端可观察到(Observable)的网络实体数目                                                                                                                                                             |
| 预表现                     | 难, 客户端需本地进行状态序列化反序列化, 进行Roll-Forth                                                              | 较易, 客户端进行预表现, 服务器进行权威演算, 客户端最终和服务器下发的状态进行调解(Reconciliation)和Roll-Forth                                                                                                                     |
| 对弱网络的适应能力         | 较低, 因为较难做到预表现, 不能做容忍处理                                                                                            | 较高, 因为较易做到预表现,较容易做容忍等                                                                                                                                                                                                         |
| 确定性                     | 严格确定性, 强一致性要求                                                                                            | 弱一致性                                                                                                                                                                                                                         |
| 版本更新                   | 较难, 无法保证一致性                                                                                                | 较易或者非常容易                                                                                                                                                                                                                 |
| 断线重连                   | 较难, 需比较耗时地进行快播追上实时进度的游戏状态                                                                    | 较易, 服务器下发当前实时游戏状态的Snapshot即可                                                                                                                                                                                   |
| 自由进出                   | 较难, 需要从起点开始计算所有逻辑,包括进出的后的玩家                                                                 | 较易, 服务器下发当前实时游戏状态的Snapshot即可                                                                                                                                                                                   |
| 离线重播(比如播放录像文件) | 较易, 且重播文件大小较小(和流量相关)                                                                                | 较易, 但重播文件较大(和流量相关)                                                                                                                                                                                                 |
| 实时重播(比如死亡重播)     | 难, 需要rollback到过去再forth到实时状态                                                                             | 较易, 服务器下发历史Snapshot给客户端回到过去、下发重播数据进行重播、再下发当前Snapshot恢复实时游戏                                                                                                                               |
| 网络逻辑性能优化           | 较难, 因为客户端需要运算所有逻辑                                                                                    | 较易, 大部分逻辑默认是在服务器进行运算, 从而分担客户端运算压力；服务器也可帮助客户端进行可观察网络对象的剔除(基于距离剔除、遮挡剔除、分块剔除等), 也可以降低优先级低的物体或属性的同步频率, 从而减小流量和再次减小客户端运算压力 |
| 大量网络实体时的流量情况   | 好, 因为流量只决定于网络玩家数目                                                                                    | 如果客户端可观察到的网络实体较少, 则较好, 比如PUBG等BattleRoyale类型；否则如果客户端可观测到的网络实体较多, 则较差, 比如Starcraft等RTS                                                                                           |
| 大量网络实体时的性能情况   | 较差, 因为客户端需要运算所有逻辑。如果大部分网络实体有 "Sleep" 的可能, 则有优化空间                                   | 如果客户端可观察到的网络实体较少, 则较好, 比如PUBG等BattleRoyale类型；否则如果客户端可观测到的网络实体较多, 则较差, 比如Starcraft等RTS                                                                                           |
| 外挂                       | 因为客户端拥有所有信息, 所以透视类外挂的影响会比较严重                                                              | 也会有透视类外挂, 但服务器会进行一定的视野剔除, 所以影响稍小                                                                                                                                                                     |
| 作弊                       | 多人竞技匹配相对还好, 少数人作弊是无效的, 但是PVE GVE同时作弊难以检测                                               | 比较困难 仲裁逻辑在服务器 做好入口防护即可有效避免                                                                                                                                                                               |
| 开发特征                   | 平时开发起来很高效, 不需前后端联调, 但写代码时需要确保确定性, 心智负担较大, 不同步bug如果出现, 对版本质量是灾难性的 | 平时开发起来效率一般, 需要前后端联调(LocalHost自测起来效率很高, 但和最终Client-Server的真实情况不尽相同, 自测应以后者为准, 故依然需要联调), 但写代码时不需确保确定性, 心智负担较小, 无不同步的bug                                |
| 开发特征2                  | 可以快速做出MVP验证                                                                                                 |                                                                                                                                                                                                                                  |
| 采用第三方库               | 较难, 因为第三方库也须确保确定性 例如导航网格 物理引擎 动画引擎                                                     | 较容易, 因为第三方库不须确保确定性                                                                                                                                                                                               |











## 同步模型的一般性描述    

在锁步同步中, 逻辑帧一般称为Tick, 而渲染帧被称为Frame,  在确定性的帧同步中不会引入物理时间, 其时间的尺度即是逻辑帧的步.   
在确定性锁步帧同步中, 其逻辑处理是一个逻辑帧一个逻辑帧执行的,  可以抽象为以下公式:   

$$
S_k=\begin{cases}
g(P, C), \qquad if \quad k = 0 \\\\
t(S_{k-1}, C, I_k),  \quad if \quad k \geq 1
\end{cases}
$$


I是游戏状态变化的根本原因的集合 往往是各个玩家(按键)操作  
S是游戏状态的集合 由众多状态子集组成  

该公式的描述: 
* 游戏在第0个逻辑帧时 根据玩家信息P和游戏配置C 进行初始化运算g 得出初始化状态集合$S_0$    
* 游戏在第k个逻辑帧时 根据前一个状态集合$S_{k-1}$和游戏配置C  根据第k帧收到的外部变化原因集合$I_k$ 进行逻辑t运算 得出第k个逻辑帧新的游戏状态集合$S_k$   
  

游戏状态的集合有关键的两个子集定义:   


$
S  \begin{cases}
O = \{ o \in S  \quad|\quad \text {o is an important state that can be observed by the player} \}  \\\\
M = \{ m \in S  \quad|\quad \text {m is an intermediate state to infer the final state} \}  
\end{cases}
$


$
S \begin{cases}
O = \{ o \in S  \quad|\quad \text {o 是一些能被玩家所明显观察到的对象的状态集合} \}   \\\\
M = \{ m \in S  \quad|\quad \text  {m 一些可用于推导最终状态的中间状态集合} \}  
\end{cases}
$


在网络同步时, 称从客户端发出信息进行网络传输的过程为上行, 称客户端经过网络传输收到信息的过程为下行:   

**一般锁步同步的本质是: 上下行都仅包含游戏外部变化原因集合$I_k$**   
**一般状态同步的本质是: 下行仅包含游戏运算得出的结果状态集合$S_k$(更精确地说是状态子集$O_k$), 上行包含$I_k$和/或状态子集$M_k$**  
   


## 游戏中的状态一致性问题   

无论是帧同步还是状态同步, 在实现上, 首先要做的是区分哪些是需要同步的状态, 而哪些是不需要关注的, 收缩解决域的规模.   

* **区分需要同步的状态和不需要同步的状态**   
  多人游戏中, 不需要同步的部分往往是指的纯本地的状态, 即其他玩家不会去感知的状态   


* **逻辑和表现分离:**   
  * 本质上, 表现是属于根据当前的状态集合$S_k$可以推导出的冗余状态以及不需要同步的细节表现部分    
    * 战斗单位受到伤害:  血量变化是状态变化, 其中变化数值和是否暴击属于计算结果,  这些属于逻辑,  根据是否暴击而选择飘红字还是蓝字 还是不飘字用其他形式展示给玩家这是伤害的表现,  血条是否要跟随发生变化, 是否需要先标注扣除的血条颜色然后清空这部分血条, 这也是表现.    
    * 在2D攻击判定中, 一个战斗角色可能有几千面三角形, 有骨骼有蒙皮有纹理,  但是逻辑上, 对于攻击判定来说, 没有这些细节 只有一个圆形+高度的圆柱体,  前者是逻辑, 后者是渲染模型和表现形式   
  * 这里关键是设计好Gamecore或者LocalServer  
  * 一般经过良好的逻辑和表现分离逻辑, 我们会拿到一份参与同步计算的纯净的状态集合$S_k$, 以方便我们进行帧同步的推演计算或者状态上的同步处理   

* **可接受弱一致性**   
  * 通常在游戏中, 我们需要保证的最终一致性而非强一致性. 例如:   
    * 可被修正的过渡状态
      * 玩家移动的位置在$S_{k}$的点a, 在$S_{k+5}$为点f,  那么玩家如果在中间b,c,d,e的点出现问题但是很快在f点再一次完成同步对齐, 其过程只要不会有肉眼可见的逻辑错误或者偏差 往往视为可接受的. (帧同步如果中间出现错误, 是不会有对齐点f的).    
      * 过渡状态会持续较长时间或者虽然时间较短但导致可感知的的逻辑结果变化 则需要具体的trade off   
       
    * 可容忍的数值偏差   
      * 例如客户端C1在发起攻击时, C1玩家的位置和服务器的位置存在一个微小偏差, 服务器可以使用C1玩家的位置来作为基准位置进行后续判定, 以达到更为精准的判定体验.   (减少位置同步对一致性的要求压力, 在PVE时效果良好, 在PVP时需要根据具体情况trade off)   

* **强一致性**   
  * 在帧同步的逻辑计算中, 我们需要严格按照公式保证所有客户端以拥有一致性的初始化, 一致性的处理逻辑, 一致性的输入, 一旦存在任何偏差, 都会在后续的每一个step中累积 最终导致完全不同的计算结果.     
  * 一致的随机数发生器,  要保证每个副本计算所用到的随机数发生器在计算过程中随机出的值一致.   
  * 计算机的浮点数计算并不保证一致性,(最近偶数) 因此涉及到浮点数计算的场合需要改为整数, 或者采用一些确定性的定点数计算   
  * 容器的增删改查,排序和遍历需要确定性   
    * std::sort非稳定排序 需要用std::stable_sort    
    * std::unorder_map之类的hash map的插入位置和遍历顺序等为实现定义, 不同的版本可能存在差异   
  * 做好逻辑层的隔离和封装, 防止意外的不确定性调用   
  * 如果计算过程引入了比如骨骼动画, 物理引擎, 导航网格等 那么也要保证其浮点数和随机数的计算确定性问题   



## 同步过程中的抖动和延迟问题    

* 输入采样延迟和事件响应延迟:  
  * 例如客户端的处理帧率是30帧, 平均采样延迟就有16.5ms  
  * 一般通过提高帧率可以改善   
   
* 逻辑处理延迟   
  * 包的序列化和反序列化延迟   
  * 多线程投递延迟   
  * 逻辑收发队列延迟(例如有的网络收发并不是实时发送和实时响应 而是采用的轮询, 类似逐帧处理下的采样延迟)   
  * 业务处理延迟
  * 通常逐帧处理方案下, 逻辑处理延迟只要保证在一帧内完成即可   

* 渲染延迟:  
  * 渲染流水线延迟  
  * 多线程渲染的同步延迟
  * 垂直同步延迟, 显示器显示延迟 像素响应延迟等    

* 网络延迟   
  * 协议栈处理延迟   
  * 链路传输延迟: 向物理介质写入的延迟   
  * 传播延迟:  物理介质内的传播速度 (例如普通光纤中光的传播速度约为真空中的2/3)   
  * 路由节点的排队处理延迟   


* 延迟抖动   
  * 网络拥堵,丢包等    
  * 逻辑处理, 例如大量的广播导致客户端一帧无法处理完所有消息包, 创建模型,场景,特效等带来的延迟超过一帧等          



## 优化网络延迟和抖动   

### 当前的网络环境    

* 骨干网在大陆内部互连时延约20ms 
  * 这个和地理位置有关, 例如从北京到深圳的直线距离 仅仅按照光纤中的光速传播延迟就折合11.4ms   
* 基站延迟  
  * 4G网络自身时延实际约30ms~40ms 在4G标准中单程为10ms
  * 5G网络自身时延实际约为6~10ms 在5G标准中单程1ms
* wifi延迟  
  * 这个因素比较多, 主要是丢包和小区宽带拥堵带来的延迟  见下网络质量图表.   

从移动通信的角度来说, 在4G时代4G接入本身是网络时延瓶颈, 5G时代骨干网为网络时延瓶颈.   


| 环境类型       | 平均时延(ms) | 抖动时延(ms) | 丢包率 | 上行带宽 | 下行带宽 |
|----------------|----------------|----------------|--------|----------|----------|
| 正常网络       | 20             | 20             | 2%     | 90%      | 90%      |
| 普通弱网络     | 30             | 100~300        | 12%    | 80%      | 60%      |
| 超低网络       | 50             | 100~500        | 30%    | 60%      | 40%      |
| 繁忙网络       | 50~100         | 30~50          | 5%     | 25%      | 25%      |
| 交通工具行驶中 | 200~400        | 200~2000       | 5%     | 60%      | 60%      |
| 地铁中         | 200~400        | 200~2000       | 12%    | 60%      | 60%      |
| 基站切换中     | 3000~7000      | 2000           | 5%     | 60%      | 60%      |

一个简单的推算, 假如客户端是30帧  
输入采样 + 基站延迟(双程) + 骨干网延迟(双程) + 服务器平均处理延迟  + 客户端渲染延迟  $\approx$  总延迟   
例如在30帧的王者荣耀中按下技能键, 全国玩家看到技能生效后的效果的总延迟在国内平均约为67ms左右.   
而如果机房在上海人在上海, 使用5G网络,  那么基本上延迟约等于客户端的帧率间隔  .  

### 工具   
* 弱网模拟器  
  * Net Limiter  守望先锋使用
  * Network Simulator
  * CCProxy
  * clumsy  

* 流量解析
  * wireshark
  * tcpdump


### 链路层延迟的优化   
* 服务器就近部署   
* 减少网络发包量和流量   
* 提高链路带宽减少排队  
* 购买专线流量提供给小ISP   
* 搭建私有专线   
  
### TCP还是UDP  
虽然目前的网络环境变得越来越好, 新的TCP拥塞控制算法例如BBR针对当下的互联网环境又做了进一步的提高,   TCP也变得越来越流行,  但是在对实时性有较高要求的游戏中, TCP对仍然显得笨拙而且有一些不合适.    


| Genre                      | Game                                          | Year  | Network Transport Protocol | Network Model | Network Topology |
|----------------------------|-----------------------------------------------|-------|----------------------------|---------------|------------------|
| RTS                        | Age of Empires[11][12]                        | 1990s | UDP                        | Lockstep      | Peer to Peer     |
| RTS                        | Starcraft I/II[11][12]                        | 1990s | UDP                        | Lockstep      | Peer to Peer     |
| RTS                        | Warcraft I/II/III/Dota[11]                    | 1990s | UDP                        | Lockstep      | Peer to Peer     |
| MMORPG                     | Ever Quest[9]                                 | 2000s | UDP                        | State Sync    | Client Server    |
| MMORPG                     | World of Warcraft[9]                          | 2000s | TCP                        | State Sync    | Client Server    |
| MMORPG                     | Lineage I/II[9]                               | 2000s | TCP                        | State Sync    | Client Server    |
| MOBA                       | League of Legends                             | 2000s | UDP                        | State Sync    | Client Server    |
| MOBA                       | DOTA2                                         | 2010s | UDP                        | State Sync    | Client Server    |
| MOBA(Mobile)               | 王者荣耀                                      | 2010s | UDP                        | Lockstep      | Client Server    |
| MOBA(Mobile)               | 全民超神                                      | 2010s | UDP                        | State Sync    | Client Server    |
| FPS                        | Doom I/II[11]                                 | 1990s | UDP                        | Lockstep      | Peer to Peer     |
| FPS                        | Quake I/II/III[11][12], Counter Strike        | 1990s | UDP                        | State Sync    | Peer to Peer     |
| FPS                        | HALO: REACH Campagin and Firefight Mode[10]   | 2010s | UDP                        | Lockstep      | Peer to Peer     |
| FPS                        | HALO: REACH Multiplayer Mode[10]              | 2010s | UDP                        | State Sync    | Peer to Peer     |
| FPS                        | Battlefield[8], Call of Duty[8][12], CS:GO[8] | 2010s | UDP                        | State Sync    | Client Server    |
| FPS(Mobile)                | 穿越火线：枪战王者                            | 2010s | UDP                        | State Sync    | Client Server    |
| FPS(+MOBA)                 | Team Fortress, Overwatch[4], Paladins         | 2010s | UDP                        | State Sync    | Client Server    |
| FPS(+BattleRoyale)         | PUBG, Fortnite                                | 2010s | UDP                        | State Sync    | Client Server    |
| FPS(+BattleRoyale)(Mobile) | 绝地求生：刺激战场, 绝地求生：全军出击        | 2010s | UDP                        | State Sync    | Client Server    |
| RAC                        | Watch Dog 2[6]                                | 2010s | UDP                        | State Sync    | Peer to Peer     |
| RAC                        | Rocket League[7]                              | 2010s | UDP                        | State Sync    | Client Server    |
| ACT                        | For Honor[5]                                  | 2010s | UDP                        | Lockstep      | Peer to Peer     |
| FTG                        | Street Fighter IV/V[8]                        | 2010s | UDP                        | Lockstep      | Peer to Peer     |
| FTG                        | Tekken 7[8]                                   | 2010s | UDP                        | Lockstep      | Peer to Peer     |
| CCG                        | Hearthstone                                   | 2010s | TCP                        | State Sync    | Client Server    |



### TCP下的延迟和抖动优化    

* 开启TCP_NODELAY 
  * 关闭Nagle算法   
  * Nagle算法原理: 在收到下一个ACK包之前, 合并(缓存)小于MSS大小的封包; 只要有已提交的数据包尚未确认, 就coalescing一定数量的数据后才提交.; 同一时间链路上(期望)只能存在一个包.   
  *  历史遗留算法 针对小带宽慢速环境, 能容忍延迟的高频小包发送情景下的优化选项. 例如ssh会话   

* 关闭TCP_CORK选项   
  * (同Nagle类似) 但是这个是完全手动控制的    因此只要不用即可    

  
* 每次recv之后开启TCP_QUICKACK立刻确认  
  * 关闭延迟确认  
  * ACK延迟确认通过合并ACK 窗口更新 响应数据, 可以将服务器发送的响应数量减少3倍    
  * ACK延迟确认和Nagle算法结合可能会导致更长的延迟,  例如发送方等待ACK才进行后续小包发送, 但是接受方因开启Delay确认收到ACK后不会立刻确认, 可能会导致总是ACK超时后才能发送数据    

* 开启SACK优化(拥塞控制)   
  * TCP通信过程中, 如果发送序列中间某个数据包丢失, TCP会重传最后确认包之后的所有包,  这里存在重复发送问题, 例如队首阻塞问题     
  * SACK则是选择性重传 可以较少重传的数据量来提高性能和优化延迟

* 启用BBR   
  * TCP诞生的年代和当下的网络环境已经发生了较大变化,  TCP的拥塞控制手段在诞生之初是主要解决的是小宽带低丢包率的环境下最大化优化互联网的吞吐,   而现在的网络情况则是大宽带但是丢包率因为无线信号传输的断续 干扰  信道串扰问题成为常态.  例如家里客厅wifi多个卧室或者卫生间的穿墙带来的丢包量大增, 乘坐交通工具穿行等.  
  * BBR的优化主要是把拥塞控制的参数从基于丢包探测改为基于实时采集的探测 对保守克制的拥塞方案进行较为开放的优化来适应当下的网络.  
    * **传统的拥塞控制是基于丢包的AIMD策略 即 和式增加 积式减少**  
    * BBR 尽量减少丢包, 瞬时时延的判定, 采用了实时采集并保留时间窗口的策略, 通过Probe More的宽带探测和Drain Less的过程(核心是完成宽带与RTT的乘积BDP计算) 来完成拥塞控制      
  * 优化和解决传统TCP拥塞控制中的以下问题:   
    * 慢启动问题  以非常小的窗口启动, 每个轮次提升窗口大小,   在大宽带情景下 要消耗特别多的轮次, 特别是大宽带高延迟情况下    
    * 慢开始问题  遇到拥塞时 乘法减少, 加性增加窗口 导致窗口的大小出现震荡并进入低速模式  
      * 虽然有快速重传和快速回复(reno版本)但是情景和效果有限   

* BBR不能解决的问题 :    
  * 通过BBR技术来说 已经缓解了大部分TCP的拥塞问题, 但是从根本上来讲 还有一些可以优化的点无法进行    
  * BBR依赖内核版本,  虽然最新的发行版已经默认启用了BBR 甚至最新的android底层也启用了这项技术,  但是 仍然不够广泛, 很多游戏服务器的环境仍然是非常老的内核版本无法应用BBR      
  * BBR版本最好的效果是双端都开启    
  * 丢包重传仍然无法减少和规避   
  * 无论数据是否可以丢弃乱序,  TCP本身都要保证所有数据的有序和完整     

### UDP的优化    
如果仅仅是用UDP重写可靠的另外一套可靠传输, 其意义相对于来说并不大 特别是有BBR之后,  那么哪些才是UDP的强项?     

* Multi-streaming 多重串流(FEC前向纠错思想)      
  * 缩水版本可以用简单的多倍发包策略来实现   
  * 在丢包后通过其他已收到的包计算出该包 从而避免丢包后的重传等待问题   
* 多通道下的可充分定制的传输选项    
  * 可靠性可选  例如普通移动包除了标记关键信息的包丢掉后不需要重传,  移动模拟从前后包插值出来后即可.    
  * 有序可选  聊天消息可以乱序接受 按照编号在UI上重排   


## 时钟选择和时钟同步      
在所有的同步方案中, 时钟校时是一个前提工作.  

**在时钟的选择上自顶向下分为两大类**   

* 逻辑时钟   
  * 和现实时间不相关, 通常帧同步中的step即是一种典型的逻辑时钟   
  * 逻辑时钟关注的是事件的时序关系, 而不关心是否和真实时间映射    
  * 可以方便做缩放处理, 例如帧同步中的快播处理,  以及帧同步中的动态调整turn/step/bucket间隔   
  * 和物理时钟相比实现和同步联调会比较麻烦
  
* 物理时钟   
  * 和系统时间相关或者直接采用std::chrono::system_clock或者std::chrono::steady_clock  
  * 和逻辑时钟相比实现简单直观 联调方便 同步问题排查也方便 

**有了时钟后就是校时, 让所有客户端和服务器的时钟对齐到时间线下**   
时钟校时基于两个前提:   

* RTT时间是相对稳定的   
* RTT往返即上行和下行延迟是接近的    

**校时的原理是通过这两个前提, 我们通过记录RTT时间并获得服务器下行的时间戳, 即可推算出服务器的时钟. 然后客户端以对齐后的时钟进行使用.**     


### 实现   
校时工作的具体实现一般分为两步    

* 初始校时   
  * 一般通过多次采样, 并通过合适的手段尽量规避掉因为DELAY ACK, NAGLE算法, MSS合并等带来的采样问题,  通过统计学的原理进行统计并获的一个小的范围 取中间值    
  
* 动态校时   
  * 网络质量存在抖动和变化, 动态校时尽量减少抖动带来的误差并跟进网络延迟的变化    
  * 参考linux早期的SRTT平滑算法  每次动态按照偏差修正一定比例 而不是覆盖    
  * $SRTT = (α \times SRTT) + ((1-α)*RTT), \quad  0.8 \leq α \geq 0.9$


## 移动: 影子跟随算法和优化(内插)    

核心流程如下:  

1. 屏幕上现实的实体(entity)只是不停的追逐它的 "影子" (shadow)
2. 服务器向各客户端发送各个影子的状态改变(坐标, 方向, 速度, 时间)
3. 各个客户端收到以后按照当前重新插值修正影子状态
4. 影子状态是跳变的, 但实体追赶影子是连续的, 故整个过程是平滑的

影子跟随算法同其名, 影子总是滞后于实体的真实位置的,  从实践上来看, 一般还需要进行一定帧的相位滞后来保证网络抖动情况下的平滑性, 延迟感会比较大, 算法本质上是 内插值+相位滞后,  因此该算法自然简单粗暴, 并且能得到非常高的一致性保证, 缺点是延迟大.         

## 常见的延迟隐藏手段   
原则上, 通过快速反馈的视觉特效, 声音特效, 不影响逻辑的动作表现, 衣物抖动, 以及可容忍的不同步状态变化等设计, 把需要等待这部分的时间分梯度过渡掉, 让玩家有整体上的及时顺畅的体验.     
* 移动的惯性加速和停止的减速  参考CS    
* 垫步动作偷位移  
* 施法时的抬手动作过渡  
* 受击假特效 例如客户端在子弹位置放击中的声效而不是等服务器通知   
* 震屏   
* 顿帧  


## 移动: 航位推测法(外推)
相位滞后+内插值来实现的影子追随算法的主要区别是在于, 航位推测法主要利用了外插值预测未来移动路线, 来达到本地位置和时间线和服务器位置与时间线的拟合,  但由于外插值的误差问题以及关键状态的瞬间改变,  航位推测法需要更多的细节优化和辅助手段来达到比较好的效果.   
通常航位预测法比较好的情景是低速或者小角速度的情景, 例如船舶航行, 赛车 .  

举例来说:  
一辆快速行驶的汽车的轨迹是可预测的, 例如它以100米/秒的速度前行, 那么1秒钟后它大概的位置在它出发点的前方100米处, 之所以这么说, 主要是因为汽车在这一秒钟内可能会有一点加速或者一点减速, 可能有一点偏航, 但汽车不会突然静止或者180度掉头(小概率正面撞山可能取决于设计需求以及进行回滚或者和解), **高速行驶的汽车的坐标高度依赖于它上一个时刻的坐标,速度,方向.**    

而类似CS这样的游戏, 玩家可以在任意时刻转弯, 并进行任意角度发生不符合现实的加速度, 外推法的意义非常有限.   


##  插值和外推, 以及常用算法  
内插值和外插值援引至数学上的概念,  一般来说都是通过已知的离散点拉一个曲线, 从曲线中获取期望的新的点.  
在游戏移动过程中, 曲线对应移动轨迹, 内插值相当于在两次移动点中间推算过程点,  而外插值则是通过已知的移动点求未来即将移动到的点  .    

### 内插值常用算法   
* 片段插值
* 线性插值
* 多项式插值
* 样条曲线插值
* 三角内插法
* 有理内插
* 小波内插

### 外插值常用算法  
* 线性外推
* 多项式外推
* 锥形外推
* 云形外推


## 命中: 延迟补偿    

前面说过, 外推法不适合CS类游戏, 那么现实其他玩家只能尽可能的用内插法, 这样就带来一个流畅性问题.   

一般来说, 玩家更多的会关注于自己的按键和反馈, 无法感知别人的按键只能感知别人的反馈,  因此选择差异性的做法,  即玩家总是根据自身的按键进行预演(自身的移动总是先于服务器), 使用内插法来显示其他玩家(其他玩家总是落后于服务器), 这样可以达到最大的流畅性. 但是这样就造就了一个新的需要解决的问题, 命中判定的双方不在一个时间轴上: 

玩家总是站在未来攻击历史上的玩家, 如果大家都在移动 那么在这样的情景下就无法正确的处理命中.    

解决这个问题的方法就成为延迟补偿,  基本策略为服务器收到了玩家的开火请求后, 根据开火请求的时间,网络延迟和差值量, 把其他玩家拉回到该玩家看到这一刻所看到的位置, 然后执行命中判定, 最后再把相应的所有玩家恢复到当前的正确位置   

步骤如下:  
* 为玩家计算一个相当精确的延迟时间
* 对每个玩家 从服务器历史信息中找一个已发送给这个玩家并且这个玩家已收到的的world update  这个world update是在这个玩家将要执行这个movement command之前的world update    
* 对于每一个玩家 将其从上述的world update处拉回到这个玩家生成此user command的更新时间中执行用户命令  这个回退时间需要考虑到命令执行的时候的网络延时和插值量     
* 执行玩家命令 包括武器开火等     
* 将所有移动的、错位的玩家移动到他们当前正确位置

### 延迟补偿的局限   
1. 延迟补偿在延迟超过一定时间后开始失效.   
2. 对于像PUBG战场这样的超远距离, 延迟补偿也会失去预期的作用    

## 逻辑预演和客户端提交命中  
在PUBG这种100名玩家的绝地岛中 想达到CS一样的延迟补偿效果是不太可能的,  一个是人数众多难以提高帧率, 另外一个是场景开阔,  失之毫厘谬以千里.    
同样类似的场景例如写实类实时动作游戏, 轻微的延迟和误差都会造成受击部位的不同, 受击时命中法线的不同, 以至于后续逻辑发生不同的分支..   

对于这种情况, 一般来说权威服务器会进一步下放权限, 客户端预演并提交命中, 服务器进行后校验.  例如PUBG的命中完全由客户端来提交.    

这样虽然解决了流畅性和精度问题, 但是也同时引出了其他的一些问题:   
* 两个玩家在延迟不同,看到的位置都有误差的情况下都提交了命中,  相信哪一个?    
* 预演失败的玩家如何进行状态纠正处理,  回滚?和解? 拉扯?  
* 客户端作弊怎么办? 

#### 满足进攻者的精彩时刻
大部分时间都会优先满足进攻者 除非受害者做了什么事情缓和（mitigate）了这次进攻  


## 提高TickRate   
在PUBG的ServerTick中  
前5分钟的的通信频率约12~24  之后会达到30帧并根据具体情况进行动态自适应调整 .  


## 回退 快播 和解   
对于帧同步而言, 一般来说会记录历史的状态切片和, 一旦出现预演失败则回退到之前的位置使用正确的输入进行快播追帧,然后进入新的预测状态   
守望先锋中:   
* 通过确定性的算法来提高预测的正确率
* 预测失败后
   在守望先锋中采用和解方法而不是直接拉扯(覆盖), 即像帧同步一样 守望先锋中的移动代码是保证确定性的 , 一旦出现预测失败则会进行重算所有输入直到追上当前时刻 并做一个平滑的处理   
 


## 案例分析部分  
略


## 引用文献   
* [多人游戏中的同步机制综述](https://zsummer.github.io/2020/07/24/2020-07-24-state_sync/)
* [TCP_NODELAY and Small Buffer Writes](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_MRG/1.2/html/Realtime_Tuning_Guide/sect-Realtime_Tuning_Guide-Application_Tuning_and_Deployment-TCP_NODELAY_and_Small_Buffer_Writes.html)
* [TCP_CORK: More than you ever wanted to know](http://baus.net/on-tcp_cork)
* [TCP/IP options for high-performance data transmission](http://www.techrepublic.com/article/tcp-ip-options-for-high-performance-data-transmission/)
* [Nginx Optimization: understanding sendfile, tcp_nodelay and tcp_nopush](https://t37.net/nginx-optimization-understanding-sendfile-tcp_nodelay-and-tcp_nopush.html)
* [The Linux Programming Interface Page 1262](https://books.google.com/books?id=2SAQAQAAQBAJ&pg=PA1262&lpg=PA1262&dq=tcp_cork&source=bl&ots=qPy0egFGus&sig=Y3_IGgidMc7K8AceiHG0UVGMwmo&hl=ja&sa=X&ei=-bsWU_bbLqm2yAGKsYG4BQ&ved=0CGMQ6AEwCDgK#v=onepage&q=tcp_cork&f=false)
* [Linux: When to use scatter/gather IO (readv, writev) vs a large buffer with fread](http://stackoverflow.com/questions/10520182/linux-when-to-use-scatter-gather-io-readv-writev-vs-a-large-buffer-with-frea)


* [Mark Frohnmayer, Tim Gift, "The TRIBES Engine Networking Model or How to Make the Internet Rock for Multi­player Games", 1998. Available: ](https://www.gamedevs.org/uploads/tribes-networking-model.pdf) [Accessed: 2019-01-27]
* [Glenn Fiedler, "State Synchronization Keeping simulations in sync by sending state", 2015, Available: ](https://gafferongames.com/post/state_synchronization/) [Accessed: 2019-01-27]
* Joshua Glazer, Sanjay Madhav, "Multiplayer Game Programming", Addison-Wesley, 2015.
* Tim Ford, "Overwatch Gameplay Architecture and Netcode", GDC, 2017.
* Xavier Guilbeault, Frederic Doll, "Deterministic vs Replicated AI Building the Battlefield of For Honor", GDC, 2017.
* Matt Delbosc, "Replicating Chaos Vehicle Replication in Watch Dogs 2", GDC, 2017.
* Jared Cone, "It IS Rocket Science! The Physics of 'Rocket League' Detailed", GDC, 2018.
* [Battle(non)sense, "Netcode & Input Lag Analyses", 2017. Available: ](https://www.youtube.com/playlist?list=PLfOoCUS0PSkXVGjhB63KMDTOT5sJ0vWy8) [Accessed: 2019-02-08]
* [Chen-Chi Wu, Kuan-Ta Chen, Chih-Ming Chen, Polly Huang, and Chin-Laung Lei, "On the Challenge and Design of Transport Protocols for MMORPGs". 2019. Available: ](http://www.iis.sinica.edu.tw/~swc/pub/tcp_mmorpg.html) [Accessed: 2019-02-08]
* [David Aldridge, "I Shot You First: Networking the Gameplay of HALO: REACH", GDC, 2011. Available: ](https://www.youtube.com/watch?v=h47zZrqjgLc) [Accessed: 2016-07-02]
* [Maksym Kurylovych, "Lockstep protocol", University of Tartu, 2008. Available: ](http://ds.cs.ut.ee/courses/course-files/Report%20-2.pdf) [Accessed: 2019-02-11]
* [Glenn Fiedler, "What Every Programmer Needs To Know About Game Networking A short history of game networking techniques", 2010. Available: ](https://gafferongames.com/post/what_every_programmer_needs_to_know_about_game_networking/) [Accessed: 2019-02-11]
* [Christophe DIOT, Laurent GAUTIER, "A Distributed Architecture for Multiplayer Interactive Applications on the Internet", IEEE, 1999. Available: ](https://www.cs.ubc.ca/~krasic/cpsc538a-2005/papers/diot99distributed.pdf) [Accessed: 2019-02-12]
* [Nathaniel E. Baughman, Brian Neil Levine, "Cheat-Proof Playout for Centralized and Distributed Online Games", IEEE INFOCOM, 2001. Available: ](https://pdfs.semanticscholar.org/2301/a3f35845baf350f65e17f6056868791854fe.pdf) [Accessed: 2019-02-12]
* [Mark Terrano, Paul Bettner, "1500 Archers on a 28.8: Network Programming in Age of Empires and Beyond", 2001. Available: ](http://www.gamasutra.com/view/feature/3094/1500_archers_on_a_288_network_.php) [Accessed: 2019-02-12]
* [Ho Lee, Eric Kozlowski, Scott Lenker, Sugih Jamin, "Multiplayer Game Cheating Prevention With Pipelined Lockstep Protocol", 2003. Available: ](http://www.ekozlowski.com/assets/multiplayer-game-cheating-prevention.pdf) [Accessed: 2019-02-12]
* ["Internet Backbone Network Latency". Available: ](https://www.dotcom-tools.com/internet-backbone-latency.aspx) [Accessed: 2019-02-15]
* ["List of interface bit rates". Available: ](https://en.wikipedia.org/wiki/List_of_interface_bit_rates) [Accessed: 2019-02-15]
* ["5G", Available: ](https://en.wikipedia.org/wiki/5G#Performance_targets) [Accessed: 2019-02-15]
* [网络游戏同步技术概述](https://www.jianshu.com/p/6ae1a6f81b01)   
* [实时对战游戏的同步——问题分析](https://www.jianshu.com/p/6ae1a6f81b01)
* [帧锁定同步算法](http://www.skywind.me/blog/archives/131)
* [从物理时钟到逻辑时钟](https://www.raychase.net/5768)
* [细谈网络同步在游戏历史中的发展变化](https://zhuanlan.zhihu.com/p/130702310)  
* [图像插值算法](https://zhuanlan.zhihu.com/p/141681355)
* [影子跟随算法](http://www.skywind.me/blog/archives/1145)
* [C/S游戏架构中延迟补偿的设计和优化方法](https://hulinhong.com/2016/01/06/latency_compensating_methods_in_client_server_in_game_protocol_design_and_optimization/)
* [《守望先锋》中的网络脚本化的武器和技能系统](https://gameinstitute.qq.com/community/detail/114122)
* [《守望先锋》中的网络同步技术](https://www.bilibili.com/video/av14551705/)
* [《守望先锋》架构设计与网络同步 -- GDC2017 精品分享实录](https://gameinstitute.qq.com/community/detail/114516)

