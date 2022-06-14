# Lecture 22: Introduction to Distributed Databases
# 22讲：分布式系统介绍

## Distributed DBMSs
## 分布式数据库系统

One can use the building blocks from single-node DBMSs to support transaction processing and query execution in distributed environments. An important goal in designing a distributed DBMS is to make it fault tolerant (i.e., to avoid a single one node failure taking down the entire system).

可以使用单节点的 DBMS 中的构建块来支持分布式环境下的事务处理和查询执行。设计分布式 DBMS 的一个重要目标是使其具有容错性（即，避免单个节点故障导致整个系统崩溃）。

Differences between parallel and distributed DBMSs:

并行和分布式 DBMS 之间的区别：

Parallel Database:

并行数据库：

• Nodes are physically close to each other.

节点在物理上彼此接近

• Nodes are connected via high-speed LAN (fast, reliable communication fabric).

节点间通过高速 LAN 连接（快速、可靠的通信结构）

• The communication cost between nodes is assumed to be small. As such, one does not need to worry about nodes crashing or packets getting dropped when designing internal protocols.

我们假设节点之间的通信成本很小。因此在设计内部协议的时候，不需要担心节点崩溃或者数据包丢失

Distributed Database:

分布式数据库：

• Nodes can be far from each other.

节点之间可以批次远离

• Nodes are potentially connected via a public network, which can be slow and unreliable.

节点可能通过公共网络连接，这可能网速比较慢并且不可靠

• The communication cost and connection problems cannot be ignored (i.e., nodes can crash, and packets can get dropped).

通信成本和连接可能出现的问题不容忽视（例如：节点可能崩溃，数据包可能丢失）

## System Architectures
## 系统架构

A DBMS’s system architecture specifies what shared resources are directly accessible to CPUs. It affects how CPUs coordinate with each other and where they retrieve and store objects in the database.

DBMS 的系统架构指定 CPU 可以直接访问哪些共享资源，它会影响 CPU 之间的协调方式，以及它们在数据库中检索和存储对象的位置

A single-node DBMS uses what is called a shared everything architecture. This single node executes workers on a local CPU(s) with its own local memory address space and disk.

单节点的 DBMS 使用所谓 ”共享一切“ 的架构。节点使用自己本地的内存地址空间和磁盘并且在本地的 CPU 上执行工作任务

### Shared Memory
### 共享内存

CPUs have access to common memory address space via a fast interconnect. CPUs also share the same disk. In practice, no one does this, as this is provided at the OS / kernel level. It causes problems, since each process’s scope of memory is the same memory address space, which could be modified by multiple processes.

CPU 可以通过快速互连访问公共内存地址空间。CPU 也共享同一个磁盘。实际上并没有人这么做，因为这是在 OS内核级别提供的。这会导致一些问题，因为每个进程的内存范围是相同的内存地址空间，这可能会被多个进程修改。

Each processor has a global view of all the in-memory data structures. Each DBMS instance on a processor has to“know” about the other instances.

每个处理器都有所有内存数据结构的全局视图。处理器上的每个 DBMS 实例都必须 ”了解“ 其他实例的情况

### Shared Disk
### 共享磁盘

All CPUs can read and write to a single logical disk directly via an interconnect, but each have their own private memories. This approach is more common in cloud-based DBMSs.

每个 CPU 都可以通过互连直接读取和写入单个逻辑磁盘，但是每个 CPU 都有自己的私有存储器。这种方法在基于云的 DBMS 中更为常见。

The DBMS’s execution layer can scale independently from the storage layer. Adding new storage nodes or execution nodes does not affect the layout or location of data in the other layer.

DBMS 的执行层可以独立于存储层进行扩展。添加新的存储节点或者执行节点不会影响其他层中数据的布局或位置

Nodes must send messages between them to learn about other node’s current state. That is, since memory is local, if data is modified, changes must be communicated to other CPUs in the case that piece of data is in main memory for the other CPUs.

节点必须在它们之间发送消息以了解其他节点的当前状态，也就是说，由于内存是本地的，如果数据被修改了，在数据库在其他 CPU 的主内存中的情况下，必须将更改传达到其他的 CPU

Nodes have their own buffer pool and are considered stateless. A node crash does not affect the state of the database since that is stored separately on the shared disk. The storage layer persists the state in the case of crashes.

节点有自己的缓冲池并且被认为是无状态的，一个节点崩溃不会影响数据库的状态，因为它单独存储在共享磁盘上，存储在在崩溃的时候持久化状态信息。

### Shared Nothing
### 无共享

Each node has its own CPU, memory, and disk. Nodes only communicate with each other via network.

每个节点都有自己的 CPU、内存和磁盘。节点仅通过网络相互通信。

It is more difficult to increase capacity in this architecture because the DBMS has to physically move data to new nodes. It is also difficult to ensure consistency across all nodes in the DBMS, since the nodes must coordinate with each other on the state of transactions. The advantage, however, is that shared nothing DBMSs can potentially achieve better performance and are more efficient then other types of distributed DBMS architectures.

在这种架构中增加系统的容量更加的困难，因为 DBMS 必须将数据物理的移动到新的节点。确保DBMS 中所有节点的一致性也很困难，因为节点必须在事务状态上相互协调。然而，优点是无共享的 DBMS 可以潜在的实现更好的性能，并且比其他类型的分布式 DBMS 架构更加高效。

### Design Issues
### 设计问题

Some design questions to consider:

一些需要考虑的设计问题:

• How does the application find data?

应用程序如何查找到数据

How should queries be executed on a distributed data? Should the query be pushed to where the data is located?

分布存储的数据应该如何查询？查询应该推送到数据所存储的地方吗？

• Or should the data be pooled into a common location to execute the query?

还是应该将数据集中到一个公共位置以执行查询？

• How does the DBMS ensure correctness?

DBMS 如何确保正确性？

Another design decision to make involves deciding between homogeneous and heterogeneous nodes, both used in modern-day systems:

要做的另一个设计决策涉及现代系统中使用的同构节点和异构节点：

Homogeneous: Every node in the cluster can perform the same set of tasks (albeit on potentially different partitions of data), lending itself well to a shared nothing architecture. This makes provisioning and failover “easier”. Failed tasks are assigned to available nodes.

同构：集群中的每个节点都可以执行相同的任务集（尽管可能在不同的数据分区上），从而很好的适用于无共享架构。这使得配置和故障转移 ”更容易“。失败的任务分配给可用的节点。

Heterogeneous: Nodes are assigned specific tasks, so communication must happen between nodes to carry out a given task. Can allow a single physical node to host multiple “virtual” node types for dedicated tasks. Can independently scale from one node to other.

异构：节点被分配了特定的任务，因此节点之间必须进行通信才能执行给定的任务。可以允许单个物理节点为专用任务托管多个”虚拟“节点类型。可以
独立的从一个节点扩展到另一个节点。

### Partitioning Schemes
### 分区方案

Split database across multiple resources, including disks, nodes, processors. This process is sometimes called sharding in NoSQL systems. The DBMS executes query fragments on each partition and then combines the results to produce a single answer. Users should not be required to know where data is physically located and how tables are partitioned or replicated. A SQL query that works on a single-node DBMS should work the same on a distributed DBMS.

跨多个资源拆分数据库，包括磁盘、节点、处理器。这个过程有时候在 NoSQL 系统中被称为分片。DBMS 在每个分区上执行查询片段，然后组合结果以产生单个答案。用户不需要知道数据节点的物理位置已经表是如何分区和复制的。在单节点上 DBMS 上运行 SQL 查询应该在分布式 DBMS 上同样运行。

We want to pick a partitioning scheme that maximizes single-node transactions, or transactions that only access data contained on one partition. This allows the DBMS to not need to coordinate the behavior of concurrent transactions running on other nodes. On the other hand, a distributed transaction accesses data at one or more partitions. This requires expensive, difficult coordination, discussed in the below section. For logically partitioned nodes, particular nodes are in charge of accessing specific tuples from a shared disk. For physically partitioned nodes, each shared nothing node reads and updates tuples it contains on its own local disk.

我们希望选择一种使得单节点事务或者仅访问包含在一个分区上的数据的事务最大化的方案。这允许 DBMS 不需要协调在其他节点上运行并发事务的行为。另一方面，分布式事务访问一个或者多个分区上的数据。这需要昂贵且困难的协调，这将在下一节讨论。对于逻辑分区节点，特定的节点负责从共享磁盘访问特定的元组。对于物理分区的节点，每个无共享节点读取和更新包含在它自己本地磁盘上的元组。

Implementation

实现

Naive Table Partitioning: Each node stores one table, assuming enough storage space for a given node. This is each to implement as a query is just routed to a specific partitioning. This can be bad, since it is not scalable. One partition’s resources can be exhausted if that one table is queried on often, not using all nodes available.

朴素表分区：每个节点存储一张表，假设给定节点有足够的存储空间。这是每个节点要实现的，因为查询只是路由到特定的分区。这可能很糟糕，因此它不可扩展。如果经常查询一个表而不使用所有可用的节点，则可能会耗尽一个分区的资源。

Horizontal Partitioning: Split a table’s tuples into disjoint subsets. Choose column(s) that divides the database equally in terms of size, load, or usage, called the partitioning key(s). The DBMS can partition a database physical (shared nothing) or logically (shared disk) via hash partitioning or range partitioning.

水平分区：将表拆分为不相交的子集。选择在大小、负载或使用方面平均划分数据库的列，它被称为分区键。DBMS 可以通过散列分区或者范围分区，对数据库进行物理分区（无共享）或者逻辑分区（共享磁盘）。

## Distributed Concurrency Control
## 分布式并发控制

If the DBMS supports multi-operation and distributed transactions, we need a way to coordinate their execution in the system.

如果 DBMS 支持多操作或者分布式事务，我们需要一种方法来协调它们在系统中的执行。

Coordinator
协调员

This is a centralized approach with a global “traffic cop” that coordinates all the behavior. The client communicates with the coordinator to acquire locks on the partitions that the client wants to access. Once it receives an acknowledgement from the coordinator, the client sends its queries to those partitions.

这是一种集中式的方法，具有协调所有行为的全局 ”交通警察“。客户端于协调员通信以获取客户端想要访问的分区上的锁。一旦收到来自协调员的确认，客户端就会将其查询发送到这些分区。

Once all queries for a given transaction are done, the client sends a commit request to the coordinator. The coordinator then communicates with the partitions involved in the transaction to determine whether the transaction is allowed to commit.

一旦完成给定事务的所有查询，客户端就会向协调员发送提交请求。然后，协调员与事务中涉及的分区进行通信，以确定是否允许提交事务。

Middleware
中间件

This is the same as the centralized coordinator except that all queries are sent to a middleware directly layer.
这与集中式协调器相同，只是所有查询都直接发送到中间件层。

Decentralized
去中心化

In a decentralized approach, nodes organize themselves. The client directly sends queries to one of the partitions. This home partition will send results back to the client. The home partition is in charge of communicating with other partitions and committing accordingly.

在分散的方法中，节点自行组织。客户端直接向其中一个分区发送查询。此主分区会将结果发送回客户端。主分区负责与其他分区进行通信并相应的提交。

Centralized approaches give way to a bottleneck in the case that multiple clients are trying to acquire locks on the same partitions. It can be better for distributed 2PL as it has a central view of the locks and can handle deadlocks more quickly. This is non-trivial with decentralized approaches.

在多个客户端尝试去获取同一个分区上的锁的情况下，它对于分布式 2PL 可能更友好，因为它具有锁的中央视图并且可以更快地处理死锁。这对于分散的方法来书并非容易的事情。
