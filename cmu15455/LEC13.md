# Lecture 13: Query Execution II 查询执行 II

## Background 背景
Our previous discussion of query execution did not specify how the DBMS would compute results. We are now going to discuss how to organize the system’s internals on the CPU.

我们之前对查询执行的讨论没有具体说明DBMS将如何计算结果。我们现在将讨论在CPU上系统内部是怎么组织。

The main goal is to understand how to enable the DBMS to support parallel query execution. This provides
several benefits:

我们的主要目标是了解如何使 DBMS 支持并行查询执行。它提供了以下好处：

• Increased performance in throughput and latency.

• 提高了吞吐和延时的性能

• Increased availability.

• 提高了可用性

• Potentially lower total cost of ownership (TCO). This cost includes both the hardware procurement and software license, as well as the labor overhead of deploying the DBMS and the energy needed to run the machines.

• 可以降低数据库系统的总体拥有成本 (TCO)。这一成本包括采购硬件以及软件许可，还有部署 DBMS 的人工开销，以及运行的机器所需要的能源开销。

The techniques discussed here are applicable to distributed DBMSs as well, so we first need to understand the differences between a parallel and distributed DBMS. These systems spread the database out across multiple “resources” to improve parallelism. These resources are either computational (e.g., CPU cores, CPU sockets, GPUs, additional machines) or storage (e.g., disks, memory).

这里讨论的技术也适用于分布式数据库系统，因此我们首先需要了解并行数据库管理系统和分布式数据库系统之间的区别。这些系统将数据库分散到多个 “资源” 中，用来提高并行性。这些资源要么是计算资源（例如 CPU 的核心，CPU 插槽，GPU, 其他的机器）或者存储设备 （例如磁盘、内存）。

## 并行数据库系统

• Nodes are physically close to each other.

节点在物理上是接近的。

• Nodes are connected with high-speed LAN.

节点之间通过高速网络互联。

• Communication cost between nodes is assumed to be fast and reliable.

节点之间的通信成本被认为是快速并且可靠的。

## 分布式数据库

• Nodes can be far from each other.

节点之间可以相隔很远

• Nodes are connected using public network.

节点之间通过公共网络互联

• Communication costs between nodes is slower and failures cannot be ignored.

节点之间通信较慢，故障不能够被忽略

Even though the database may be physically divided over multiple resources, it still appears as a single logical database instance to the application. Thus, the SQL query for a single-node DBMS should generate the same result on a parallel or distributed DBMS.

即使数据库可以在物理上被划分为多个资源，但它对应用程序来说仍然是一个单一逻辑的数据库实例。因此，应用单节点数据库系统与并行或者分布式数据库系统执行相同的操作返回的结果是一样的。

## 并行类型
• Inter-Query: The DBMS executes different queries are concurrently. This increases throughput and reduces latency. Concurrency is tricky when queries are updating the database.

数据库系统同时执行不同的查询。这增加了吞吐量并减少了延迟。但是当查询更新数据库时处理并发比较棘手。

Intra-Query: The DBMS executes the operations of a single query in parallel. This decreases latency for long-running queries.

数据库并发的执行单个操作，这降低了长查询的延迟。

## Process Models 过程模型
A DBMS process model defines how the system supports concurrent requests from a multi-user application/environment. The DBMS is comprised of more or more workers that are responsible for executing tasks on behalf of the client and returning the results.

DBMS 的过程模型定义了系统如何支持来自多用户应用程序/环境的并发请求。DBMS 由一个或者多个 worker 组成，它们负责执行任务并返回给客户端结果。

## Approach 1 – Process per Worker: 每个 worker 由独立进程实现

• Each worker is a separate OS process, and thus relies on OS scheduler.

每个 worker 都是一个独立的操作系统进程，因此这会依赖操作系统的调度器。

• Use shared memory for global data structures.

对全局数据结构存储使用共享内存（可以用于多个 worker 进程之间通信）。

• A process crash does not take down entire system.

一个进程崩溃不会导致整个系统崩溃。

## Approach 2 – Process Pool: 进程池

• A worker uses any process that is free in a pool.

worker 可以使用池中任何空闲的进程。

• Still relies on OS scheduler and shared memory.

仍然是依赖操作系统调度以及共享内存。

• This approach can be bad for CPU cache locality due to no guarantee of using the same process between queries.

由于无法保证在查询之间使用相同的进程，因此这种方法可能会对 CPU 的缓存
https://en.wikipedia.org/wiki/Locality_of_reference 局部性造成不利的影响。

## Approach 3 – Thread per Worker: 每个 worker 由独立线程实现

• Single process with multiple worker threads.

有多个 worker 线程的独立进程实现。

• DBMS has to manage its own scheduling.

DBMS 需要管理它自己的调度策略。

• May or may not use a dispatcher thread.

可以选择使用或者不使用一个单独的调度线程。

• Although a thread crash (may) kill the entire system, we have to make sure that we write high-quality code to ensure that this does not happen.

一个线程崩溃（可能）会杀死整个系统，我们必须确保编写高质量的代码，以确保不会发生这种情况。

Using a multi-threaded architecture has advantages that there is less overhead per context switch and you do not have to manage shared model. The thread per worker model does not mean that you have intra-query parallelism.

使用多线程体系结构的优点是：每个上下文切换的开销较小，并且你不需要管理共享模型。每个 worker 一个线程的模型并不意味着你有 intra-query 的并行性。

For each query plan, the DBMS has to decide where, when, and how to execute:

对于每个查询计划，DBMS 必须决定在何处、何时以及如何执行它？

• How many tasks should it use?

它需要使用多少个任务？

• How many CPU cores should it use?

它需要使用多少 CPU 核心数？

• What CPU core should the tasks execute on?

任务应该在哪个 CPU 内核上执行？

• Where should a task store its output?

任务应该在哪里存储其输出？

## Inter-Query Parallelism  查询间的并行性
The goal of this type of parallelism is to improve the DBMS’s overall performance by allowing multiple queries to execute simultaneously.

这种并行性的目标是通过同时允许执行多个查询来提高 DBMS 的整体性能。在后续讨论并发控制协议的时候，我们将会更加详细的介绍这一点。

## Intra-Query Parallelism  查询内的并行性
The goal of this type of parallelism is to improve the performance of a single query by executing its operators in parallel. There are parallel algorithms for every relational operator.

这种并行性的目标是通过并行执行单个查询的运算符来提高性能的，每个运算符都有对应的并行算法。

## Intra-Operator Parallelism 算子内并行

The query plan's operators are decomposed into independent instances that perform the same function on different subsets of data.

查询计划的运算被分解为独立的实例，这些实例对不同的数据子集执行相同的操作。

The exchange operator prevents the DBMS from executing operators above it in the plan until it receives all of the data from the children.

exchange 运算符阻止 DBMS 在计划中执行其上方的运算符，直到它从子系统收到所有数据。

In general, there are three types of exchange operators:

一般来说有3种 exchange 运算符。

• Gather: Combine the results from multiple workers into a single output stream. This is the most common type used in parallel DBMSs.

聚集：将多个 worker 的工作结果写入到一个输出流中，这是并行 DBMS 中最常见的类型。

• Repartition: Reorganize multiple input streams across multiple output streams. This allows the DBMS take inputs that are partitioned one way and then redistribute them in another way.

重新分区：跨越多个输出流重新组织输入流。这允许 DBMS 以一种方式对输入进行分区，然后以另一种方式重新分配他们。

• Distribute: Split a single input stream into multiple output streams.

分发：将单个输入流拆分成多个输出流。


Inter-Operator Parallelism  算子间并行


The DBMS overlaps operators in order to pipeline data from one stage to the next without materialization. This is sometimes called pipelined parallelism.

为了将数据从一个阶段输送到下一个阶段，DBMS 的操作符重叠，无需具体化。这通常被叫做流水线并行。

This approach is widely used in stream processing systems, systems that continually execute a query over a stream of input tuples.

这种方法广泛应用于流处理系统中，这些系统通过输入元组流持续进行查询操作。

Bushy Parallelism  浓密并行

Extension of inter-operator parallelism where workers execute multiple operators from different segments of a query plan at the same time.

运算符间并行性的扩展，其中 worker 同时执行来自一个查询计划的不同的操作运算。

The DBMS still uses exchange operators to combine intermediate results from these segments.

DBMS 仍然使用 exchange 运算符来组合这些段的中间结果。

## I/O Parallelism  I/O 并行
Using additional processes/threads to execute queries in parallel will not improve performance if the disk is always the main bottleneck. Thus, we need a way to split the database up across multiple storage devices.

如果磁盘是主要瓶颈，那么使用额外的进程和线程去执行并行的查询并不能提高系统整体的性能。因此，我们需要一个在多个存储设备上拆分数据库的办法。

## Multi-Disk Parallelism  多磁盘并行化
Configure OS/hardware to store the DBMS’s files across multiple storage devices. Can be done through storage appliances and RAID configuration. This is transparent to the DBMS. It cannot have workers operate on different devices because it is unaware of the underlying parallelism.

配置操作系统/硬件设备去跨越多个存储设备存储 DBMS 的文件。可以通过存储设备和 RAID 配置来完成。这对 DBMS 来说是透明的。它不能让 worker 在不同的设备上操作因为它并不了解底层的并行性。

## File-based Partitioning  基于文件的分区
Some DBMSs allow you to specify the disk location of each individual database. The buffer pool manager maps a page to a disk location. This is also easy to do at the file-system level if the DBMS stores each database in a separate directory. However, the log file might be shared.

有些 DBMS 允许你指定每个数据库磁盘的位置，缓冲池将页面映射到磁盘。如果数据库管理系统将不同的数据库存储到不同的目录，那么在文件系统级别很容易做到这一点。但是，日志文件可能是共享的。

## Logical Partitioning  逻辑分区
Split single logical table into disjoint physical segments that are stored/managed separately. Such partitioning is ideally transparent to the application. That is, the application should be able to access logical tables without caring how things are stored.

将单个逻辑表拆分成独立存储/管理不相交的物理段，这种分区对应用程序来说是透明的。也就是说应用程序去访问逻辑表可以不关心底层的存储形式。


## Vertical Partitioning  垂直分区
• Store a table’s attributes in a separate location (like a column store).

将表的属性分开存储到不同的位置（像列存储）

• Have to store tuple information to reconstruct the original record.

必须存储元信息以重建原始记录。

## Horizontal Partitioning  水平分区

• Divide the tuples of a table into disjoint segments based on some partitioning keys.

根据一些分区键将表的元组划分为不相交的段。

• There are different ways to decide how to partition (e.g., hash, range, or predicate partitioning). The efficacy of each approach depends on the queries.

有很多的方法来决定如何分区，（例如：哈希，范围，谓词分区）。每种方法的效果取决于具体的查询。
