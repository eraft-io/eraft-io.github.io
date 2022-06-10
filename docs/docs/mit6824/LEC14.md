Lecture 13: Spanner

Why this paper (Google Spanner, OSDI 2012)?
A rare example of wide-area distributed transactions.
广域（全球多活）下实现分布式事务罕见的案例
Very desirable.
非常值得拥有
But two-phase commit viewed as too slow and prone to blocking.
但是两阶段提交被认为太慢，而且容易阻塞

A rare example of wide-area synchronous replication.
广域（全球多活）下实现同步复制罕见的案例

Neat ideas:
干净的想法

Two-phase commit over Paxos.
在 paxos 上进行两阶段提交

Synchronized time for fast r/o transactions.
快速的事务，通过同步的时钟

Used a lot inside Google.
在谷歌内部被大范围使用

What was the motivating use case?
Spanner 的动机是什么？

Google F1 advertising database (Section 5.4).
谷歌 F1 广告数据库

Previously sharded over many MySQL and BigTable DBs; awkward.
之前是存储在多个 MySQL 和 BigTable 数据库上，这么做事很尴尬的

Needed:
需求

Better (synchronous) replication.
更好的（同步）复制方案

More flexible sharding.
更灵活的分片架构

Cross-shard transactions.
跨越多个分片的事务

Workload is dominated by read-only transactions (Table 6).
工作负载主要由只读事务控制

Strong consistency is required.
需要强一致性保证

External consistency / linearizability / serializability.
外部一致性 、线性化、串行化

The basic organization:
基本的组织

Datacenter A:
数据中心 A

"clients" are web servers e.g. for gmail
客户端是 WEB 服务器，例如 GMAIL

data is sharded over multiple servers:
数据在多个服务器上分片
a-m
n-z

Datacenter B:
数据中心 B 

has its own local clients
有自己本地的客户端

and its own copy of the data shards
有它自己的数据分片拷贝
a-m
n-z

Datacenter C:
same setup
相同的配置

Replication managed by Paxos; one Paxos group per shard.
由 Paxos 管理数据复制，一个 Paxos 分组负责一个分片

Replicas are in different data centers. 
副本位于不同的数据中心

Similar to Raft -- each Paxos group has a leader.
与 Raft 类似，每个 paxos 分组都有一个  leader

As in the labs, Paxos replicates a log of operations.
和我们课程的实验一样，paxos 分组内复制这操作的日志


Why this arrangement?
为什么这么安排？

Sharding allows huge total throughput via parallelism.
分片的实现允许并行的访问实现巨大的总吞吐量

Datacenters fail independently -- different cities.
数据中心的故障是独立的，不同的城市

Clients can read local replica -- fast!
客户端可以直接从本地副本读取数据 — 加速访问

This is what's driving the design's timestamps and TrueTime.
这就是设计时间戳和 TrueTime 的驱动力

Can place replicas near relevant customers.
可以在相关客户的附近放置副本

Paxos requires only a majority -- tolerate slow/distant replicas.
Paxos 只需要多数派复制，可以容忍缓慢、远距离的复制

What are the challenges?
挑战是什么？

Data on local replica may not be fresh.
本地的副本上数据可能不是最新的

Local replica may not reflect latest Paxos writes!
本地的副本可能不能反映最新的 paxos 写入

A transaction may involve multiple shards -> multiple Paxos groups.
一个事务可能设计多个 shard -> 多个 paxos 分组

Transactions that read multiple records must be serializable.
读取多条记录的事务必须是可串行化的

But local shards may reflect different subsets of committed transactions!
但是本地的 shard 可能反应不同提交的事务的不同子集

Spanner treats read/write and read/only transactions differently.
Spanner 以不同的方式处理读/写 和 只读事务

First, read/write transactions.
读写事务

Example read/write transaction (bank transfer):
我们看一个读写事务的例子（银行转账）

BEGIN
x = x + 1
y = y - 1
END

We don't want any read or write of x or y sneaking between our two ops.
我们不希望在我们的两次操作之间, 有任何的对 x,y 的读写

After commit, all reads should see our updates.
在提交之后，所有的读者，都应该看到我们的更新操作

Summary: two-phase commit (2pc) with Paxos-replicated participants.
总结：两阶段提交（2PC），paxos 复制组作为事务参与者

(Omitting timestamps for now.)
(暂时省略时间戳)

(This is for r/w transactions, not r/o.)
(这是对于针对读写事务，不包括只读事务)

Client picks a unique transaction id (TID).
客户端选择唯一的事务 id (TID)

Client sends each read to Paxos leader of relevant shard.
客户端将每次要读取的内容发送给负责相关数据分片的 paxos 组 leader

Each shard first acquires a lock on the relevant record.
每个分片首先获取到相关记录的锁

May have to wait.
可能需要等待

Separate lock table per shard, in shard leader.
在分片的 leader 中，每个分片都有单独的锁表

Read locks are not replicated via Paxos, so leader failure -> abort.
读锁不会通过 paxos 复制，所以一旦 leader 挂了 -> 事务中断

Client keeps writes private until commit.
客户端在事务提交之前保持写入的私有性（其他的事务看不到此事务的修改）

When client commits (4.2.1):
当客户端提交的时候

Chooses a Paxos group to act as 2pc Transaction Coordinator (TC).
选择一个 paxos 分组作为 2pc 事务协调器（TC）

Sends writes to relevant shard leaders.
向分片相关的 leader 发送写请求

Each written shard leader:
每个被写的分片 leader：

Acquires lock(s) on the written record(s).
获取写入记录的锁

Log a "prepare" record via Paxos, to replicate lock and new value.
通过 paxos 日志写入 “prepare”  记录，以复制锁和新值

Tell TC it is prepared.
告诉事务协调器它准备好了

Or tell TC "no" if crashed and thus lost lock table.
如果发生故障并失去锁表，会告诉事务协调器，它还没有准备好

Transaction Coordinator:
事务协调者

Decides commit or abort.
决定提交或者中止事务

Logs the decision to its group via Paxos.
通过 paxos 把决策记录到它的复制组中

Tell participant leaders and client the result.
告诉参与的分片 leader 以及客户端结果

Each participant leader:
每个作为参与者的领导

Log the TC's decision via Paxos.
通过  paxos 日志记录 TC 的决策

Perform its writes.
执行写入

Release the transaction's locks.
释放事务的锁

Some points about the design so far (just read/write transactions).
到目前为止，关于设计的一些要点（只对于读写事务来说）

Locking (two-phase locking) ensures serializability.
锁（两阶段锁定）来保证可串行化

2pc widely hated b/c it blocks with locks held if TC fails.
2pc 广为诟病的 b/c，如果 TC 发生故障，它会阻塞

Replicating the TC with Paxos solves this problem!
用 paxos 复制 TC 来解决了这个问题，（复制保证高可用）

r/w transactions take a long time.
读写事务需要花很长的时间

Many inter-data-center messages.
数据中心之前很多消息交互

Table 6 suggests about 100 ms for cross-USA r/w transaction.
论文中表 6 显示，跨越美国的读写事务大约需要 100ms

Much less for cross-city (Table 3).
跨越城市的场景耗时就更少了（见表 3）

But lots of parallelism: many clients, many shards.
但有很多并行性：许多客户端，许多数据分片

So total throughput could be high if busy.
所以如果事务繁忙，总的吞吐量可以达到很高

From now on I'll mostly view each Paxos group as a single entity.
从现在起，我将每个 paxos 分组视为一个单独的实体

Replicates shard data.
复制分片数据

Replicates two-phase commit state.
复制到两阶段提交的状态

Now for read-only (r/o) transactions.
现在我们看到只读事务

These involve multiple reads, perhaps from multiple shards.
这涉及到多个读取操作，可能跨越多个分片

We'd like r/o xactions to be much faster than r/w xactions!
我们希望只读事务要比读写事务快很多

Spanner eliminates two big costs for r/o transactions:
Spanner 消除了只读事务的两大成本

Read from local replicas, to avoid Paxos and cross-datacenter msgs.
从本地读取，避免跨越数据中心的消息传递

But note local replica may not be up to date!
但请注意，本地的副本可能不是最新的

No locks, no two-phase commit, no transaction manager.
没有锁，没哟两阶段提交，没有事务管理器

Again to avoid cross-data center msg to Paxos leader.
再次降低向  paxos leader 发送跨越数据中心的消息

And to avoid slowing down r/w transactions.
避免拖慢读写事务

Tables 3 and 6 show a 10x latency improvement as a result!
结果，论文中表3和表6显示延迟提升了 10 倍

This is a big deal.
这是一件大事

How to square this with correctness?
如何将其与正确性进行比较

Correctness constraints on r/o transactions:
只读事务的正确性约束

Serializable:
可序列化

Same results as if transactions executed one-by-one.
结果和逐个执行事务相同

Even though they may actually execute concurrently.
即使他们实际上可能同时执行

I.e. an r/o xaction must essentially fit between r/w xactions.
一个只读事务基本上匹配读写事务之前

See all writes from prior transactions, nothing from subsequent.
查看之前事务中的所有写入，后续事务中没有任何写入

Even though *concurrent* with r/w xactions! And not locking!
即使并行的没有锁的操作读写事务

Externally consistent:
外部一致性

If T1 completes before T2 starts, T2 must see T1's writes.
如果 T1 在 T2 开始之前完成，那么 T2 必须看到 T1 的写入操作

"Before" refers to real (wall-clock) time.
“之前”是指实际（挂钟）时间

Similar to linearizable.
类似于线性化

Rules out reading stale data.
排除读取到过时数据的可能性
