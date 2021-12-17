关于 ERaft
我们是一个致力于解读国外优质计算机视频课程的组织，同时，我们也在设计和开发原创的分布式数据库系统  [https://github.com/eraft-io/eraft](https://github.com/eraft-io/eraft) , 创建这个小站点，准备以知乎小视频的方式给大家解读国外的优质计算机课程。

## 解读系列


### CMU 15-445/645 (数据库系统) 课程解读列表

|      |   Course Name |
| ---- | ---- | 
|      |   [DataBase Storage I-LEC3-001-存储设备](https://www.zhihu.com/zvideo/1427745101607399424)   |  
|      |   [DataBase Storage I-LEC3-002-磁盘存储系统概述](https://www.zhihu.com/zvideo/1431029555611570176) |
|      |   [DataBase Storage I-数据库管理系统 vs OS](https://www.zhihu.com/zvideo/1431030608751865857) |
|      |   [DataBase Storage I-LEC3-004-文件存储和数据库页面](https://www.zhihu.com/zvideo/1435359815837462528) |
|      |   [DataBase Storage I-LEC3-005-数据库堆文件](https://www.zhihu.com/zvideo/1435361376004505600)   | 
|      |   [Database Storage II-LEC4-01-数据表示](https://www.zhihu.com/zvideo/1435366167381168128) |  
|      |   [Database Storage II-LEC4-02-工作负载](https://www.zhihu.com/zvideo/1435366772677074944) | 
|      |   [Database Storage II-LEC4-03-存储模型](https://www.zhihu.com/zvideo/1438210703048511488) | 
|      |   [Buffer Pools-LEC5-01-锁与闩锁](https://www.zhihu.com/zvideo/1440815156519915520) |  
|      |   [Buffer Pools-LEC5-02-BufferPool 概念](https://www.zhihu.com/zvideo/1441886640976990208)  |
|      |   [Buffer Pools-LEC5-03-BufferPool 优化（一）](https://www.zhihu.com/zvideo/1445164566070661120)  |
|      |   [Buffer Pools-LEC5-03-BufferPool 优化（二）](https://www.zhihu.com/zvideo/1445408456384176128)  |
|      |   [Hash Tables-LEC6-01-数据结构](https://www.zhihu.com/zvideo/1440257210513846272)  |   
|      |   [Hash Tables-LEC6-02-哈希表](https://www.zhihu.com/zvideo/1441153726552076289)   |  
|      |   [Hash Tables-LEC6-03-哈希函数](https://www.zhihu.com/zvideo/1442601114054758400)  | 
|      |   [Hash Tables-LEC6-04-静态哈希方案](https://www.zhihu.com/zvideo/1443706414753959936)  | 
|      |   [Hash Tables-LEC6-04-罗宾汉哈希](https://www.zhihu.com/zvideo/1443998804417073152)  | 
|      |   [Hash Tables-LEC6-04-布谷鸟哈希](https://www.zhihu.com/zvideo/1444371854048210944)  | 
|      |   [Tree Indexes Part I-LEC7-01-B+树简介](https://www.zhihu.com/zvideo/1449819247724077056)  | 
|      |   [Tree Indexes Part I-LEC7-02-B+树叶子节点](https://www.zhihu.com/zvideo/1450451803079274496)  | 
|      |   [Tree Indexes Part I-LEC7-03-B+树插入](https://www.zhihu.com/zvideo/1451526175349104640)  | 

### MIT 6.828 (操作系统) 课程解读系列

|      |   Course Name |
| ---- | ---- | 
|      |     |  

### 项目开发

![https://github.com/eraft-io/eraft-io.github.io/raw/master/ekv_1.png](https://github.com/eraft-io/eraft-io.github.io/raw/master/ekv_1.png)

#### E-META
主要存储一些集群 meta 数据，这个模块本身是一个只有一个 region 的 e-store，里面存储了当前集群的 region 信息，每个 store 节点的信息。每次 E-DB 接收到数据写入请求后会先访问 E-META 去找到数据所在的 store 节点，以及 peer 地址，然后再连接这个地址写数据进去。

#### E-KV
这个是具体存储数据的节点，最小部署 3 节点，它们可以组成一个或者多个 Raft Group 对 E-DB 提供高可用的存储服务，同时 E-STORE 会定期的上报 E-META 节点信息，看是否需要扩容分裂，E-STORE 具有自动分裂的能力。

[点此查看详细设计](https://eraft.cn/ekv)

## 参考
[1] [https://learncs.me](https://learncs.me)

[2] [https://15445.courses.cs.cmu.edu/fall2019/schedule.html](https://15445.courses.cs.cmu.edu/fall2019/schedule.html)

[3] [https://pdos.csail.mit.edu/6.828/2020/schedule.html](https://pdos.csail.mit.edu/6.828/2020/schedule.html)
