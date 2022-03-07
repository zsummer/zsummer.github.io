
---
title: detour crowd  
date: 2022-03-07
categories: develop 
author: yawei.zhang 
mathjax: false
---


算法笔记
<!--more -->

## 走廊空间: DetourPathCorridor.h :   class dtPathCorridor;          

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
基于(约束于)navmesh行走面的内的位置变化(移动)处理.   
* 从旧的位置往新的位置去找, 如果不在同一个poly则往相邻的poly去找,  如果不可达或者位置无效, 则得到的坐标和传入的期望位置可能会不同   
* 

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