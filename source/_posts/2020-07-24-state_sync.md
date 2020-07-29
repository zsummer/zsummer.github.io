---
title: 多人游戏中的同步机制综述 
date: 2020-07-24
categories: develop 
author: yawei.zhang 
mathjax: true
---

## 前言    
本文中所有内容默认都基于逻辑描述, 逻辑状态,逻辑处理的逻辑游戏世界,  纯本地表现类, 总是通过逻辑世界单向导出的渲染计算等, 均不在本篇文章讨论范畴.  


## 同步问题的产生和基本策略机制  

**在多人游戏或者基于CS网络模型的游戏中, 玩家所在的游戏世界并非全由本地生成和修改, 必须不断从服务器或者其他玩家获得最新的信息来完成游戏世界的共享体验, 在多人实时交互的游戏中,  相当于每个人都维护一个'完整世界'的副本, 并保证每个人维护的副本之间一致性和实时性, 不同游戏对副本的规模复杂度以及对一致性和实时性的要求不同, 在不同的历史时期的演进下则产生了多种同步方案来实现这一要求.**   


在所有的同步方案中, 有两种最基础也最常见的同步机制, 即状态同步和帧同步, 其基本机制和区别为:  

* **状态同步: 直接描述则为 通过同步游戏中的各种状态来保证游戏世界副本的一致性, 基本流程如下:**   
  * 服务器维护权威完整副本  客户端维护本地副本 <font color=#ccc> (可以只维护部分副本) </font>   
  * 客户端上行请求到服务器 服务器进行完整的逻辑演算 并将发生改变的状态下行给客户端   
  * <font color=#ccc>客户端基于本地副本进行预演和状态预刷新 </font>  
  * 客户端用来自服务器的状态数据刷新本地副本, 对齐服务器副本   
    * <font color=#ccc>客户端如果有因预演导致的数据不对齐需要通过强同步/回滚/和解等机制达成最终对齐</font>   
      * <font color=#ccc>快照类同步方式总是全量对齐</font>   

  
* **帧同步: 直接描述其基本原理则为: 通过一致的初始副本和一致的输入事件与一致的逻辑处理, 来保证游戏世界副本的一致性**  
  * 帧同步的变种和演化分支比较多
    * 是否锁步分为帧锁定同步和定时不等待的乐观锁同步两种模式   
    * 网络拓扑是对等还是CS模式, 鼻祖DOOM1最开始为P2P对等网络的锁步同步, 后来改为CS模式的锁步同步  
    * 是否存在权威节点, 分为主机模式和非主机模式  
  
  * 锁步同步:  
    * 客户端定时(比如每五帧)上传控制信息   
    * 服务器收到所有控制信息后广播给所有客户端  
    * 客户端用服务器发来的更新消息中的控制信息进行游戏(如果是对称网络, 这个过程则是广播和搜集所有其他客户端的信息)     
    * 如果客户端进行到下一个关键帧(5帧后)时没有收到服务器的更新消息则等待   
    * 如果客户端进行到下一个关键帧时已经接收到了服务器的更新消息，则将上面的数据用于游戏，并采集当前鼠标键盘输入发送给服务器，同时继续进行下去   
    * 服务端采集到所有数据后再次发送下一个关键帧更新消息   
  
  * 定时不等待:     
    * 相对于锁步同步来说, 服务器会定时下发收集到的信息,  并根据收集到的信息调整关键帧的间隔,  没有在指定间隔内收到的消息会排在下一次关键帧或者丢弃   
    * 相对于锁步同步来说, 任何客户端的卡顿不会阻塞其他玩家   

<!-- more -->   

| .                          | 锁步同步                                                                                                            | 状态同步                                                                                                                                                                                                                         |
|----------------------------|---------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 流量                       | 一般情况下较低, 决定于网络玩家数目                                                                                  | 一般情况下较高, 决定于当前该客户端可观察到(Observable)的网络实体数目                                                                                                                                                             |
| 预表现                     | 难, 客户端需本地进行状态序列化反序列化, 进行Roll-Forth                                                              | 较易, 客户端进行预表现, 服务器进行权威演算, 客户端最终和服务器下发的状态进行调解(Reconciliation)和Roll-Forth                                                                                                                     |
| 对弱网络的适应能力         | 较低, 因为较难做到预表现                                                                                            | 较高, 因为较易做到预表现                                                                                                                                                                                                         |
| 确定性                     | 严格确定性, 强一致性要求                                                                                            | 弱一致性                                                                                                                                                                                                                         |
| 版本更新                   | 较难, 无法保证一致性                                                                                                | 较易或者非常容易                                                                                                                                                                                                                 |
| 断线重连                   | 较难, 需比较耗时地进行快播追上实时进度的游戏状态                                                                    | 较易, 服务器下发当前实时游戏状态的Snapshot即可                                                                                                                                                                                   |
| 自由进出                   | 较难, 需要从起点开始计算所有逻辑,包括进出的后的玩家                                                                 | 较易, 服务器下发当前实时游戏状态的Snapshot即可                                                                                                                                                                                   |
| 离线重播(比如播放录像文件) | 较易, 且重播文件大小较小(和流量相关)                                                                                | 较易, 但重播文件较大(和流量相关)                                                                                                                                                                                                 |
| 实时重播(比如死亡重播)     | 难, 需要rollback到过去再forth到实时状态                                                                             | 较易, 服务器下发历史Snapshot给客户端回到过去、下发重播数据进行重播、再下发当前Snapshot恢复实时游戏                                                                                                                               |
| 网络逻辑性能优化           | 较难, 因为客户端需要运算所有逻辑                                                                                    | 较易, 大部分逻辑默认是在服务器进行运算, 从而分担客户端运算压力；服务器也可帮助客户端进行可观察网络对象的剔除(基于距离剔除、遮挡剔除、分块剔除等), 也可以降低优先级低的物体或属性的同步频率, 从而减小流量和再次减小客户端运算压力 |
| 大量网络实体时的流量情况   | 好, 因为流量只决定于网络玩家数目                                                                                    | 如果客户端可观察到的网络实体较少, 则较好, 比如PUBG等BattleRoyale类型；否则如果客户端可观测到的网络实体较多, 则较差, 比如Starcraft等RTS                                                                                           |
| 大量网络实体时的性能情况   | 较差, 因为客户端需要运算所有逻辑。如果大部分网络实体有“Sleep”的可能, 则有优化空间                                   | 如果客户端可观察到的网络实体较少, 则较好, 比如PUBG等BattleRoyale类型；否则如果客户端可观测到的网络实体较多, 则较差, 比如Starcraft等RTS                                                                                           |
| 外挂                       | 因为客户端拥有所有信息, 所以透视类外挂的影响会比较严重                                                              | 也会有透视类外挂, 但服务器会进行一定的视野剔除, 所以影响稍小                                                                                                                                                                     |
| 作弊                       | 多人竞技匹配相对还好, 少数人作弊是无效的, 但是PVE GVE同时作弊难以检测                                               | 比较困难 仲裁逻辑在服务器 做好入口防护即可有效避免                                                                                                                                                                               |
| 开发特征                   | 平时开发起来很高效, 不需前后端联调, 但写代码时需要确保确定性, 心智负担较大, 不同步bug如果出现, 对版本质量是灾难性的 | 平时开发起来效率一般, 需要前后端联调(LocalHost自测起来效率很高, 但和最终Client-Server的真实情况不尽相同, 自测应以后者为准, 故依然需要联调), 但写代码时不需确保确定性, 心智负担较小, 无不同步的bug                                |
| 开发特征2                  | 可以快速做出MVP验证                                                                                                 |                                                                                                                                                                                                                                  |
| 采用第三方库               | 较难, 因为第三方库也须确保确定性 例如导航网格 物理引擎 动画引擎                                                     | 较容易, 因为第三方库不须确保确定性                                                                                                                                                                                               |



需要注意的是, **这两者并不冲突并能相互借鉴补充**, 在上述的简单描述中通过灰色部分注明了一部分常见的相互补充方式,  通常在具体的实践中会对同步策略进行细节的定制以及相互补充来达到相对项目最好的同步效果, 典型的是DS服务器和存在完整逻辑演算的帧同步服务器.      








## 同步模型的一般性描述    

在锁步同步中, 逻辑帧一般称为Tick, 而渲染帧被称为Frame,  在确定性的帧同步中不会引入物理时间, 其时间的尺度即是逻辑帧的步.   
在确定性锁步帧同步中, 其逻辑处理是一个逻辑帧一个逻辑帧执行的,  可以抽象为以下公式:   

$$
S_k=\begin{cases}
g(P, C), \qquad if \quad K > 0 \\\\
t(S_{k-1}, C, I_k),  \quad if \quad K \geq 0
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
  多人游戏中, 这部分往往是指的纯本地的状态, 即其他玩家不会去感知的状态   


* **逻辑和表现分离:**   
  * 本质上, 表现是属于根据当前的状态集合$S_k$可以推导出的冗余状态以及不需要同步的细节表现部分    
    * 战斗单位受到伤害:  血量变化是状态变化, 其中变化数值和是否暴击属于计算结果,  这些属于逻辑,  根据是否暴击而选择飘红字还是蓝字 还是不飘字用其他形式展示给玩家这是伤害的表现,  血条是否要跟随发生变化, 是否需要先标注扣除的血条颜色然后清空这部分血条, 这也是表现.    
    * 在2D攻击判定中, 一个战斗角色可能有几千面三角形, 有骨骼有蒙皮有纹理,  但是逻辑上, 对于攻击判定来说, 没有这些细节 只有一个圆形+高度的圆柱体,  前者是逻辑, 后者是渲染模型和表现形式   
  * 这里关键是设计好Gamecore或者LocalServer  
  * 一般经过良好的逻辑和表现分离逻辑, 我们会拿到一份参与同步计算的纯净的状态集合$S_k$, 以方面我们进行帧同步的推演计算或者状态上的同步处理, 接下来要做的事情是对这其进一步规整拆解   

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
  * 计算机的浮点数计算并不保证一致性, 因此涉及到浮点数计算的场合需要改为整数, 或者采用一些确定性的定点数计算   
  * 容器的增删改查,排序和遍历需要确定性   
    * std::sort非稳定排序 需要用std::stable_sort    
    * std::unorder_map之类的hash map的插入位置和遍历顺序等为实现定义, 不同的版本可能存在差异   
  * 做好逻辑层的隔离和封装, 防止意外的不确定性调用   
  * 如果计算过程引入了比如骨骼动画, 物理引擎, 导航网格等 那么也要保证其浮点数和随机数的计算确定性问题   



## 同步过程中的抖动和延迟问题    

* 输入采样延迟:  
  * 例如客户端的处理帧率是30帧, 平均采样延迟就有16.5ms  
  * 这个通过提高帧率可以改善   
* 指令逐帧处理延迟:  
  * 这个其实对应的是采样延迟, 如果不是基于实时事件响应的, 无论是按键输入还是网络包的处理 都会有平均半帧的延迟   

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


| 环境类型       | 平均时延（ms） | 抖动时延（ms） | 丢包率 | 上行带宽 | 下行带宽 |
|----------------|----------------|----------------|--------|----------|----------|
| 正常网络       | 20             | 20             | 2%     | 90%      | 90%      |
| 普通弱网络     | 30             | 100~300        | 12%    | 80%      | 60%      |
| 超低网络       | 50             | 100~500        | 30%    | 60%      | 40%      |
| 繁忙网络       | 50~100         | 30~50          | 5%     | 25%      | 25%      |
| 交通工具行驶中 | 200~400        | 200~2000       | 5%     | 60%      | 60%      |
| 地铁中         | 200~400        | 200~2000       | 12%    | 60%      | 60%      |
| 基站切换中     | 3000~7000      | 2000           | 5%     | 60%      | 60%      |

一个简单的推测, 假如客户端是30帧  
输入采样 + 基站延迟(双程) + 网络延迟(双程) + 服务器平均处理延迟  + 客户端渲染延迟  $\approx$  总延迟   
例如在30帧的王者荣耀中按下技能键, 玩家看到技能生效后的效果的总延迟在国内平均约为67ms左右.   

### 工具   
* 弱网模拟器  
  * Net Limiter  守望先锋使用
  * Network Simulator
  * CCProxy

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
  * 可靠性可选  例如普通移动包除了标记关键信息的包丢掉后不需要重传,  移动模拟从前后包差值出来后即可.    
  * 有序可选  聊天消息可以乱序接受 按照编号在UI上重排   


## 同步的基础校时工作    

## 隐藏等待  博弈    

## 预演 回退  快进  和解   


## 案例部分  



## 综合实践案例   


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


* "ENet: An UDP networking layer for the multiplayer first person shooter cube," http://enet.cubik.org/.
* "FAQ - Multiplayer and Network Programming," GameDev.Net, 2004. [Online]. Available: http://www.gamedev.net/
* M. Allman, V. Paxson, and W. Stevens, "TCP congestion control," RFC 2581, Apr. 1999.
* R. Braden, "Requirements for internet hosts - communication layers," RFC 1122, Oct. 1989.
* K.-T. Chen, P. Huang, and C.-L. Lei, "Game Traffic Analysis: An MMORPG Perspective," Computer Networks, vol. 50, no. 16, pp. 3002-3023, Nov 2006.
* --, "How Sensitive are Online Gamers to Network Quality??" Communications of the ACM, vol. 49, no. 11, pp. 34-38, Nov 2006.
* --, "Effect of network quality on player departure behavior in online games," IEEE Transactions on Parallel and Distributed Systems, vol. 20, no. 5, pp. 593-606, May 2009.
* M. Claypool, "The effect of latency on user performance in real-time strategy games," Elsevier Computer Networks, special issue on Networking Issues in Entertainment Computing, vol. 49, no. 1, Sep 2005.
* M. Claypool and K. Claypool, "Latency and player actions in online games," Communications of the ACM, vol. 49, no. 11, Nov 2006.
* S. Floyd and E. Kohler, "Profile for datagram congestion control protocol (DCCP) congestion control ID 2: TCP-like congestion control," RFC 4341, March 2006.
* S. Floyd, E. Kohler, and J. Padhye, "Profile for datagram congestion control protocol (DCCP) congestion control ID 3: Tcp-friendly rate control (TFRC)," RFC 4342, March 2006.
* "OpenTNL: The Torque network library," GarageGames, April 2004, http://www.opentnl.org/.
* C. Griwodz and P. Halvorsen, "The fun of using TCP for an MMORPG," in NOSSDAV '06: Proceedings of the 2006 international workshop on Network and operating systems support for digital audio and video, 2006, pp. 1-7.
* S. Harcsik, A. Petlund, C. Griwodz, and P. Halvorsen, "Latency evaluation of networking mechanisms for game traffic," in NetGames '07: Proceedings of the 6th ACM SIGCOMM Workshop on Network and System Support for Games, 2007, pp. 129-134.
* E. Kohler, M. Handley, and S. Floyd, "Datagram congestion control protocol (DCCP)," RFC 4340, March 2006.
* M. Mathis, J. Mahdavi, S. Floyd, and A. Romanow, "TCP selective acknowledgement options," RFC 2018, Oct. 1996.
* S. Pack, E. Hong, Y. Choi, llkyu Park, J.-S. Kim, and D. Ko, "Game transport protocol: lightweight reliable transport protocol for massive interactive on-line game," in Proceedings of the SPIE, vol. 4861, 2002, pp. 83-94.
* S. Shirmohammadi and N. D. Georganas, "An end-to-end communication architecture for collaborative virtual environments," Computer Networks, vol. 35, no. 2-3, pp. 351-367, 2001.
* R. W. Stevens, TCP/IP Illustrated, Volume 2: The Implementation.    Addison-Wesley, 1995.
* R. Stewart, "Stream control transmission protocol," RFC 4960, September 2007.
* "ShenZhou Online," UserJoy Technology Co., Ltd., http://www.ewsoft.com.tw/.
* B. S. Woodcock, "An analysis of MMOG subscription growth - version 23.0." [Online]. Available: http://www.mmogchart.com/