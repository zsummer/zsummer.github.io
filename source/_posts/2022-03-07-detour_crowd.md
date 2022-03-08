
---
title: detour crowd实现之corridor   
date: 2022-03-07
categories: develop 
author: yawei.zhang 
mathjax: false
---


算法笔记
<!--more -->

## 走廊空间: DetourPathCorridor.h :   class dtPathCorridor;          


### 基本术语参考   

* vertex: 多边形顶点
* Corridor : 多边形组成的连通区域 : 走廊,  对于更上层的pathfinding而言, poly被被抽象为点与点的连通关系. 这里展开后则为走廊.    
* poly: 多边形: 一个多边形包含基础的顶点信息和link信息和基础类型数据等.     
* Surface:  表面(行走面), 概念上为行走面, 在这里的实现则为poly组成的mesh表面   
* mesh: 网, 概念上指的是指的由poly组成行走面的数据结构方式, 即mesh;  连通图.   
* Corners: 挂点, 概念上是指的corridor走廊中的边上的顶点  通常为墙角(pathfinding近似最优解, 也是期望, 但未必总是 例如tile带来的边界)   
* moveAlongSurface: 约束在行走面上的位置移动处理  
* neis,eighbour: 邻居, 避让中的邻居为agent; corridor中的邻居则是poly  
* node: 一般为脚手架, 即用于临时性的list的节点.  navigation的实现封装层次较低, 不同结构中的node意义不同.   
* edge: 概念上的边, 是link最主要的类型之一, 第一个边一般是指的下标0的顶点连向下一个顶点的边, 这里要注意 link是一个分离实现的链表, 一个当前poly的边可能有多个link标记属于当前边   
*  visited: 可认为是爬过(访问过)     
* Off-mesh connections: 概念上是连线, 实现是poly: 只有两个边两个顶点的poly, 可双向连通;  即第一个link指向第一个边(顶点0)且该link指向的poly不是出发点点poly的的时候为连出, 否则为连入.   处于off-mesh移动的agent无法进行避让处理(不做避让处理).     DT_OFFMESH_CON_BIDIR 标记为双向的offlink会同时添加在目标poly和源poly的link中.  而off-mesh poly本身没有双向还是单向的标记. 也不需要.   
  

数据结构   
```C++
class dtPathCorridor
{
    float m_pos[3];  //该坐标位于'm_path[0]'中   
    float m_target[3]; //目标点应位于'm_path[m_npath-1]'中  
    
    //初始化时候一次性预分配好poly数组所需要的内存;     
    dtPolyRef* m_path;  //这里存储的是poly id数组组成的路径id   在这里概念上叫做corridor 即从起始点到目标点有效的走廊空间 
    int m_npath;
    int m_maxPath;
};

/// The current corridor position is expected to be within the first polygon in the path. The target 
/// is expected to be in the last polygon. 

```

```
/**
@class dtPathCorridor
@par

The corridor is loaded with a path, usually obtained from a #dtNavMeshQuery::findPath() query. The corridor
is then used to plan local movement, with the corridor automatically updating as needed to deal with inaccurate 
agent locomotion.

Example of a common use case:

-# Construct the corridor object and call #init() to allocate its path buffer.
-# Obtain a path from a #dtNavMeshQuery object.
-# Use #reset() to set the agent's current position. (At the beginning of the path.)
-# Use #setCorridor() to load the path and target.
-# Use #findCorners() to plan movement. (This handles dynamic path straightening.)
-# Use #movePosition() to feed agent movement back into the corridor. (The corridor will automatically adjust as needed.)
-# If the target is moving, use #moveTargetPosition() to update the end of the corridor. 
   (The corridor will automatically adjust as needed.)
-# Repeat the previous 3 steps to continue to move the agent.

The corridor position and target are always constrained to the navigation mesh.

One of the difficulties in maintaining a path is that floating point errors, locomotion inaccuracies, and/or local 
steering can result in the agent crossing the boundary of the path corridor, temporarily invalidating the path. 
This class uses local mesh queries to detect and update the corridor as needed to handle these types of issues. 

The fact that local mesh queries are used to move the position and target locations results in two beahviors that 
need to be considered:

Every time a move function is used there is a chance that the path will become non-optimial. Basically, the further 
the target is moved from its original location, and the further the position is moved outside the original corridor, 
the more likely the path will become non-optimal. This issue can be addressed by periodically running the 
#optimizePathTopology() and #optimizePathVisibility() methods.

All local mesh queries have distance limitations. (Review the #dtNavMeshQuery methods for details.) So the most accurate 
use case is to move the position and target in small increments. If a large increment is used, then the corridor 
may not be able to accurately find the new location.  Because of this limiation, if a position is moved in a large
increment, then compare the desired and resulting polygon references. If the two do not match, then path replanning 
may be needed.  E.g. If you move the target, check #getLastPoly() to see if it is the expected polygon.

*/
```


dtPathCorridor简述:   
通过pathfinding给出来的poly path, 在pathfinding看来是一系列连通的点, 但是解开成poly后,  则是一系列相邻的poly组成的走廊空间.   
corridor则是在走廊空间中进行局部移动规划(pathfinding是高级路径规划), 包括如何从一个poly走向另外一个poly, 移动转向,  避让带来的局部更新等.    比喻的话, pathfinding相当于导航地图给出来的路线,   而corridor则是通过雷达&摄像头等实时扫描绘制出来用于驾驶决策的现场交通环境.   


### dtPathCorridor   
该函数设置新的路径和目标坐标点位置  但未处理起始点坐标.  
```C++
/// The current corridor position is expected to be within the first polygon in the path. The target 
/// is expected to be in the last polygon. 
/// @warning The size of the path must not exceed the size of corridor's path buffer set during #init().
void dtPathCorridor::setCorridor(const float* target, const dtPolyRef* path, const int npath)
{
    dtVcopy(m_target, target);
    memcpy(m_path, path, sizeof(dtPolyRef)*npath);
    m_npath = npath;
}
```

###  fixPathStart
修复起始点坐标,  
这里将会覆盖路径点中的第一个和第二个.    但是如果当前路径个数为1或者2  则会保留最后一个  
0的作用略过.  
```C++
bool dtPathCorridor::fixPathStart(dtPolyRef safeRef, const float* safePos)
{
    dtVcopy(m_pos, safePos);
    if (m_npath < 3 && m_npath > 0)
    {
        m_path[2] = m_path[m_npath-1];
        m_path[0] = safeRef;
        m_path[1] = 0;
        m_npath = 3;
    }
    else
    {
        m_path[0] = safeRef;
        m_path[1] = 0;
    }
    return true;
}
```

### movePosition
基于(约束于)navmesh行走面的内的位置变化(移动)处理, 新的位置仍然位于m_path[0]中.    
* 这种移动可能导致组成走廊空间的拓扑非最优 以及 移动的路径非最优.  
* 从旧的位置往新的位置沿着poly mesh行走面去找, 如果不在同一个poly则往相邻的poly去找,  如果不可达或者位置无效, 则得到的坐标和传入的期望位置可能会不同   
* 找到新的有效位置后合并路径: 先通过moveAlongSurface找到从当前点到移动目标点的poly visited 路径, 然后用这个路径和现有路径进行合并. 
  * 例如如果新路径为已有路径的下个poly, 则减去当前poly(预期情况1);  
  * 例如当前移动仍然在m_path[0]的poly内, 则合并去重(预期情况2) (这里其实发生不必要的拷贝请求(memmove对相同地址和长度的请求应该不会执行));
  * 如果避让跑偏了走到了新的poly, 则把当前path整体后移, 把当前移动带来的新的走廊path拼接起来, 拼接过程会尽可能的优化掉重复的的路径, 但是按照这个拼接  从走廊上来说是增加了新的走廊长度 因此需要通过局部visted重新优化局部路径.   
```C++
bool dtPathCorridor::movePosition(const float* npos, dtNavMeshQuery* navquery, const dtQueryFilter* filter)
{
    // Move along navmesh and update new position.
    float result[3];
    static const int MAX_VISITED = 16;
    dtPolyRef visited[MAX_VISITED];
    int nvisited = 0;
    dtStatus status = navquery->moveAlongSurface(m_path[0], m_pos, npos, filter,
                                                 result, visited, &nvisited, MAX_VISITED);
    if (dtStatusSucceed(status)) {
        m_npath = dtMergeCorridorStartMoved(m_path, m_npath, m_maxPath, visited, nvisited);
        
        // Adjust the position to stay on top of the navmesh.
        float h = m_pos[1];
        navquery->getPolyHeight(m_path[0], result, &h);
        result[1] = h;
        dtVcopy(m_pos, result);
        return true;
    }
    return false;
}
```

### dtNavMeshQuery::moveAlongSurface  

DT_VERTS_PER_POLYGON = 6;  navigation中最大单个poly有6个顶点  
沿着navmesh表面移动时, 最多stack ```MAX_STACK = 48``` 个poly节点, 超过后会丢弃.  
每次移除当前poly并检查是否为目标点所在poly时, 如果没找到, 则添加所有符合条件的邻居到stack中,   
每次stack邻居时, 这些邻居都通过pidx指向该poly(node) :  反向树结构 父节点不知道只节点, 但子节点知道父节点.   起始点所在poly为root node.      
当我们找到目标点的所在的poly时候, 通过node->pidx 可以反向串起来完整的走廊空间.  逆序保存为 visited poly数组  
每次visit一个poly时 会stack这个poly的所有邻居(过滤后)  
 

```C++
dtStatus dtNavMeshQuery::moveAlongSurface(dtPolyRef startRef, const float* startPos, const float* endPos,
                                          const dtQueryFilter* filter,
                                          float* resultPos, dtPolyRef* visited, int* visitedCount, const int maxVisitedSize) const
{
    //....   
    dtNode* startNode = m_tinyNodePool->getNode(startRef);
    startNode->pidx = 0;
    startNode->cost = 0;
    startNode->total = 0;
    startNode->id = startRef;
    startNode->flags = DT_NODE_CLOSED;
    stack[nstack++] = startNode;


    //....   

    while (nstack)
    {
        // Pop front.
        dtNode* curNode = stack[0];
        for (int i = 0; i < nstack-1; ++i)
            stack[i] = stack[i+1];
        nstack--;
        
        //....   


        // If target is inside the poly, stop search.
        if (dtPointInPolygon(endPos, verts, nverts))
        {
            bestNode = curNode;
            dtVcopy(bestPos, endPos);
            break;
        }

        //....   
        for (int i = 0, j = (int)curPoly->vertCount-1; i < (int)curPoly->vertCount; j = i++)
        {
             //....   
            if (filter->passFilter(link->ref, neiTile, neiPoly))
            {
                if (nneis < MAX_NEIS)
                    neis[nneis++] = link->ref;
            }
             //....   
        }
        for (int k = 0; k < nneis; ++k)
        {
            //....   
            if (nstack < MAX_STACK)
            {
                neighbourNode->pidx = m_tinyNodePool->getNodeIdx(curNode);
                neighbourNode->flags |= DT_NODE_CLOSED;
                stack[nstack++] = neighbourNode;
            }
            //....   
        }
    }

        int n = 0;
    if (bestNode)
    {
        // Reverse the path.
        dtNode* prev = 0;
        dtNode* node = bestNode;
        do
        {
            dtNode* next = m_tinyNodePool->getNodeAtIdx(node->pidx);
            node->pidx = m_tinyNodePool->getNodeIdx(prev);
            prev = node;
            node = next;
        }
        while (node);
        
        // Store result
        node = prev;
        do
        {
            visited[n++] = node->id;
            if (n >= maxVisitedSize)
            {
                status |= DT_BUFFER_TOO_SMALL;
                break;
            }
            node = m_tinyNodePool->getNodeAtIdx(node->pidx);
        }
        while (node);
    }
    dtVcopy(resultPos, bestPos);
    *visitedCount = n;
}
 ```

### dtMergeCorridorStartMoved
合并path路径和visted路径.  见movePosition说明  

 ```C++
int dtMergeCorridorStartMoved(dtPolyRef* path, const int npath, const int maxPath,
							  const dtPolyRef* visited, const int nvisited)
{
	int furthestPath = -1;
	int furthestVisited = -1;
	
	// Find furthest common polygon.
	for (int i = npath-1; i >= 0; --i)
	{
		bool found = false;
		for (int j = nvisited-1; j >= 0; --j)
		{
			if (path[i] == visited[j])
			{
				furthestPath = i;
				furthestVisited = j;
				found = true;
			}
		}
		if (found)
			break;
	}
	
	// If no intersection found just return current path. 
	if (furthestPath == -1 || furthestVisited == -1)
		return npath;
	
	// Concatenate paths.	
	
	// Adjust beginning of the buffer to include the visited.
	const int req = nvisited - furthestVisited;
	const int orig = dtMin(furthestPath+1, npath);
	int size = dtMax(0, npath-orig);
	if (req+size > maxPath)
		size = maxPath-req;
	if (size)
		memmove(path+req, path+orig, size*sizeof(dtPolyRef));
	
	// Store visited
	for (int i = 0; i < req; ++i)
		path[i] = visited[(nvisited-1)-i];				
	
	return req+size;
}
```



## dtPathCorridor::findCorners
走廊的关键实现之一 其核心是findStraightPath, 即查找直线路径上的拐点.   是agent移动能力的核心支持.   
该函数从起点到终点查找拐点数量 失败或超过最大数量或者遇到off-link poly后停止    


## optimizePathVisibility
该函数通过局部可视化优化agent在走廊中的移动路线, 即当可以直线可达下个路点时候 拉直路线  
动态避让, tile边界都会导致移动路线和走廊空间非最优.   




## optimizePathTopology  
和可视化不同, 这个是通过局部寻路进行修正和确认当前走廊是否为最优.   
