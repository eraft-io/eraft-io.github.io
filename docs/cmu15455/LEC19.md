# Lecture 19: Multi-Version Concurrency Control  多版本并发控制

Multi-Version Concurrency Control (MVCC) is a larger concept than just a concurrency control protocol. It involves all aspect of the DBMS’s design and implementation. MVCC is the most widely used scheme in DBMS. It is now used in almost every new DBMS implemented in last 10 years. Even some systems (e.g., NoSQL) that do not support multi-statement transactions use it.

多版本并发控制（MVCC）是一个比并发控制协议更大的概念。它涉及 DBMS 设计与实现的所有方面。MVCC 是 DBMS 中使用最广泛的方案，它现在几乎用于过去 10 年所实现的所有的数据库系统。甚至一些不支持多语句事务系统的数据库也支持它 (例如 NoSQL)

The DBMS maintains multiple physical versions of a single logical object in the database.

DBMS 维护了数据库中单个逻辑对象的多个物理版本

• When a transaction writes to an object, the DBMS creates a new version of that object.

• 当事务写入一个对象时，DBMS 会创建该对象的新版本

• When a transaction reads an object, it reads the newest version that existed when the transaction started.

• 当一个事务读取一个对象时，它会读取事务开始时数据库中存储的值得最新的版本

The original MVCC protocol for DBMSs was first proposed in 1978 MIT PhD dissertation. The first imple- mentation in a real DBMS was in InterBase (now open-sourced as Firebird) by Jim Starkey, who later went on to be the co-founder of NuoDB.

DBMS 的原始 MVCC 协议于 1978 年 MIT 博士论文中首次提出。真正 DBMS 中第一个实现是由 Jim Starkey 在 InterBase 中实现的，他后来成为了 NuoDB 的联合创始人


### Key Properties

Writers don’t block the readers. Readers don’t block the writers.

Read-only transactions can read a consistent snapshot without acquiring locks. Timestamps are used to determine visibility.

Multi-versioned DBMSs can support time-travel queries that can read the database at a point-in-time snapshot.

There are four important MVCC design decisions:

1. Concurrency Control Protocol (T/O, OCC, 2PL, etc). 

2. Version Storage

3. Garbage collection

4. Index Management

### 关键的特性

写操作不回阻塞读操作，读操作不会阻塞写操作

只读事务可以在不获取锁的情况下读取一致的快照，时间戳用来确定数据的可见性

多版本的数据库管理系统可以支持在不同时间点读取数据库快照数据

四个关于 MVCC 设计的重要决策

- 并发控制协议 (T/O，OCC，2PL，etc)

- 版本存储

- 垃圾回收

- 索引管理

# Version Storage  版本存储

This how the DBMS will store the different physical versions of a logical object.

这是关于数据库管理系统如果存储逻辑对象的不同物理版本的方式

The DBMS uses the tuple’s pointer field to create a version chain per logical tuple. This allows the DBMS to find the version that is visible to a particular transaction at runtime. Indexes always point to the head of the chain. A thread traverses chain until you find the version that is visible to you. Different storage schemes determine where/what to store for each version.

DBMS 使用元组的指针字段来为每个逻辑元组创建一个版本链。这允许 DBMS 找到在特定事务运行时后可见的版本。索引总是指向链的头部，一个线程遍历链，知道找到可见的版本。不同的存储方案决定了每个版本数据存储的位置/内容

### Approach 1: Append-Only Storage – New versions are appended to the same table space.

#### 方式1: 仅追加存储-新版本的数据被追加到相同的表空间

- Oldest-To-Newest (O2N) : Append new version to end of chain, look-ups require entire chain traversal.

- Oldest-To-Newest (O2N) : 新版本追加到链的末尾，查找需要遍历整个链

- Newest-To-Oldest (N2O): Head of chain is newest, look-ups are quick, but indexes need to be updated every version.

- Newest-To-Oldest (N2O): 链头是最新的，查找速度很快，但是每个版本都需要更新索引

### Approach 2: Time-Travel Storage – Old versions are copied to separate table space.

### 方法2：时间链存储 - 将旧版本的值复制到单独的表空间

### Approach 3: Delta Storage – The original values of the modified attributes are copied into a separate delta record space.

### 方法3: 增量存储 - 修改后的属性被拷贝到一个单独的增量记录空间

# Garbage Collection 垃圾回收

The DBMS needs to remove reclaimable physical versions from the database over time.

DBMS 需要随着时间的推移从数据库中删除可以回收的版本

Approach 1: Tuple Level Garbage Collection – Find old versions by examining tuples directly

方法1：元组垃圾收集器 - 通过直接检查元组来查找旧的版本

- Background Vacuuming: Separate threads periodically scan the table and look for reclaimable versions, works with any version storage scheme.

- 后台清理: 单独的县城定期的扫描并寻找可以被回收的版本，适用于任何版本存储的方案

- Cooperative Cleaning: Worker threads identify reclaimable versions as they traverse version chain. Only works with O2N.

- 协作清理：工作线程在遍历版本链的时候识别可以回收的版本，仅适用于 O2N

## Approach 2: Transaction Level  事务级别

Each transaction keeps track of its own read/write set. When a transaction completes, the garbage collector can use that to identify what tuples to reclaim. The DBMS determines when all versions created by a finished transaction are no longer visible.

每个事务都跟踪自己的读/写集。 当事务完成时，垃圾收集器可以使用它来识别要回收的元组。 DBMS 确定由已完成事务创建的所有版本何时不再可见。

# Index Management 索引管理

All primary key (pkey) indexes always point to version chain head. How often the DBMS has to update the pkey index depends on whether the system creates new versions when a tuple is updated. If a transaction updates a pkey attribute(s), then this is treated as a DELETE followed by an INSERT.

所有主键 (pkey) 索引始终指向版本链头，DBMS 需要多久更新一次 pkey 索引取决于系统是否在更新元组时创建新版本。如果事务更新了 pkey 属性，则将其视为先 DELETE 后跟 INSERT。

Managing secondary indexes is more complicated:

管理二级索引更复杂

- Approach 1: Logical Pointers – Use a fixed identifier per tuple that does not change. Requires an extra indirection layer that maps the logical id to the physical location of the tuple (Primary Key vs Tuple ID).

- 方法一：逻辑指针 - 每个元组使用一个不变的标识符。需要一个额外的间接层，将逻辑 ID 映射到元组的物理位置 （主键 VS 元组 ID）

- Approach 2: Physical Pointers – Use the physical address to the version chain head

- 方法二：物理指针 - 使用版本链头的物理地址
