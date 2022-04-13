**本文知识结构如下**

![在这里插入图片描述](https://images.gitbook.cn/42006ca0-2544-11eb-84f6-71decbee3f6f)

### Raft 算法概述

Raft 是一种易于理解和工程实现的一致性算法，它最早是由斯坦福的 Diego Ongaro 和 John Ousterhout 提出，他们的研究致力于实现一种比 Paxos 简单，并且容易工程实现的一致性算法，他们的研究成果的论文是《In Search of an Understandable Consensus Algorithm》，这篇文论文只是讲到了 Raft 算法的核心概念，并没有涉及到工程实现上的很多细节之处，为此，作者还发布了一个更详细的文章《Consensus: Bridging Theory and Practice》建议大家读下这篇文章，etcd-raft 库基本就是照着这论文思路来实现的。

我们先来看到第一个问题，一致性算法到底要解决什么问题？下图是一致性算法研究中最基础的复制状态机：

![在这里插入图片描述](https://images.gitbook.cn/4a630470-20fd-11eb-9df9-d3d52bf54dd3)

图中有多个服务器 (Server)，一致性算法的目的就是要保证对于一组操作 (图中 Log 由这些操作日志组成)，我们的算法能够保证操作按顺序，都在服务器各自的状态机 (State Machine) 上执行，并且状态机最终的状态是一致的。这样，对于客户端来说，就算其中一些服务器宕机的情况下，系统也可以继续的提供服务，也是我我们通常说的实现服务的高可用。

### Raft 算法 Leader 选举流程详解

raft github 官网给出了算法的动画演示: http://thesecretlivesofdata.com，以下算法流程的描述都来自这个动画演示。

1.每个 Follower 都持有一个定时器，并产生一个随机的定时时间。

![在这里插入图片描述](https://images.gitbook.cn/49fedb80-20e9-11eb-8365-699b47800ee5)

2.当定时器到了而集群中仍然没有 Leader 被选出，Follower 状态变成 Candidate 并参与 Leader 选举，同时发送消息给其他节点来争取它们的投票，如果其他节点长时间没有响应 Candidate 将重新发送选举信息。

3.集群中其他节点给 Candidate 投票。

![在这里插入图片描述](https://images.gitbook.cn/55481bf0-20e9-11eb-a4e2-cb9ae83384d2)

4.获得多数票数 (半数节点以上) 的 Candidate 变成 Leader ，并且它的 Term (任期号) 是最新的。

![在这里插入图片描述](https://images.gitbook.cn/64af4910-20e9-11eb-b5f3-2790cae1607f)

5.在任期内 Leader 会不断发送心跳给其他节点证明自己还活着，其他节点收到心跳以后就清空自己的计时器并回复 Leader 的心跳。这个机制可以保证其他节点不会在 Leader 的任期内参加 Leader 选举。

![在这里插入图片描述](https://images.gitbook.cn/74f3b6d0-20e9-11eb-8070-f18bd6c4c7a3)

6.当 Leader 节点出现故障而导致 Leader 失联，没有接收心跳的 Follower 节点将会变成 Candidate 状态重新进入下一轮选举。

![在这里插入图片描述](https://images.gitbook.cn/81f5a3c0-20e9-11eb-b5f3-2790cae1607f)

7.如果两个 Candidate 同时赢得选举获得了相同的票数（概率很小），那么这两个 Candidate 将随机推迟一段时间后再向其他节点发出投票请求，这样就保证了再次发送投票请求以后不冲突。

![在这里插入图片描述](https://images.gitbook.cn/8af47f00-20e9-11eb-8365-699b47800ee5)

### Raft 算法日志复制流程详解

1.Leader 负责接收来自 client 的提案请求。。

![在这里插入图片描述](https://images.gitbook.cn/76a19dd0-20fd-11eb-9df9-d3d52bf54dd3)

2.提案的内容将被包含在 Leader 发出的下一个心跳包中发送给 Follower。

3.Follower 接收到心跳以后回复 Leader 心跳包。

4.Leader 接收到多数派 Follower 的回复以后确认提案并写入自己的状态机并回复 Client。

5.Leader 通知所有 Follower 节点确认提案并写入自己的状态机，之后所有节点状态集中拥有一致的数据。

![在这里插入图片描述](https://images.gitbook.cn/8a9d9550-20fd-11eb-a524-5fc5a6b28db5)

6.当集群中出现网络异常，导致集群被分割，将出现多个 Leader

7.被分割出的非多数派集群将无法达到共识（数据无法应用到状态机中），即脑裂，如下图 A，B 无法确认提案。

![在这里插入图片描述](https://images.gitbook.cn/82159af0-2101-11eb-8365-699b47800ee5)

8.当集群再次连通时，将只听从最新任期 Leader 的指挥，旧（任期更低）的 Leader 将退化成 Follower，如下图中 B 节点（任期 1 的 Leader ）将听从 C 节点（任期 3 的 Leader ）的指挥，此时集群状态重新变成一致。

![在这里插入图片描述](https://images.gitbook.cn/90a5ac80-2102-11eb-9c9d-f390c29a896c)

### Raft 算法安全性保证分析

前面的算法流程描述都是正常流程，我们没有去讨论异常情况下的 Raft 算法的安全性保证；然而实际的分布式系统是不可避免出现各种异常的，比如网络不可用，集群中机器故障等异常场景，那么接下来我们来看看论文里面对 Raft 安全性保障的一些讨论。

我们可以大致的分为选举限制和日志提交限制两个方向讨论：

#### 选举限制

在 Raft 协议中，所有日志项都只会从 Leader 节点往 Follower 节点写入，且 Leader 节点上的日志只会增加，绝对不会删除或者覆盖。那么这就意味着 Leader 上包含了所有已经提交的日志，也就是被选举成 Leader 的节点一定包含所有已经完成提交操作的日志。因为日志只会从 Leader 向 Follower 传输，所以如果被选举出来的 Leader 上缺少了已经 Commit 的日志，那么这些已经提交的日志就会丢失，显然这是不符合要求的。Leader 的选举限制可以总结成：能被选举成为 Leader 节点，那么它一定包含了所有已经提交的日志。

接下来我们结合协议中具体 RequestVote RPC 请求来分析：

![在这里插入图片描述](https://images.gitbook.cn/3553f0b0-22e9-11eb-8593-595337b851a9)

请求中的 lastLogIndex 和 lastLogTerm 即用于保证 Follower 投票选出的被 Leader 节点一定包含了已经提交的日志项。

1. Candidate (候选者) 需要收到超过版本的节点的选票来成为 Leader
2. 已经 Commit (提交) 的日志至少存在于超过半数的节点上

日志的比较规则：Raft 通过比较两份日志中最后一条日志条目的索引值和任期号定义谁的日志更新。如果两份日志最后的日志条目的任期号不同，那么任期号大的日志更新。如果两份日志最后的日志条目项任期号相同，那么日志比较长的那个就更新。

#### 日志提交的限制

![在这里插入图片描述](https://images.gitbook.cn/ebdb6dd0-22ea-11eb-9df9-d3d52bf54dd3)

这张图按时间序列展示了 Leader 在提交日志的时候可能会遇到的问题。

 1. 在 (a) 中，S1 是领导者，部分的复制了索引位置 2 的日志条目。
 2. 在 (b) 中，S1 崩溃了，然后 S5 在任期 3 里面通过 S3、S4 和自己的选票赢得选举，然后客户端接收了一条不一样的日志条目放在了索引号为 2 的地方。
 3. 让后到 (c) 的时候，S5 有奔溃了；S1 重新启动，选举成功过，开始复制日志。在这时，来自任期 2 的那条日志就已经被复制到了大多数机器上，但是还没有被提交。
 4. 如果 S1 在 (d) 的时候又崩溃了，S5 可以重新被选举成功（通过来自 S2，S3 和 S4 的选票），然后覆盖了他们在索引 2 处的日志。反之，如果在奔溃之前，S1 把自己主导的新任期内产生的日志条目复制到了大多数机器上，就像 (e) 中那样，那么在后面的任期里面这些新的日志条目就会被提交（因为 S5 不可能选举成功）。这样在同一时刻就保证了，之前的所有老的日志条目就会被提交。

### Etcd-Raft 详解

#### 与 Etcd-Raft 库交互

etcd raft 库的实现在 etcd/raft 目录下，可以参考这份代码的注释详细阅读 [跳转](https://github.com/lichuang/etcd-3.1.10-codedump/tree/master/raft)

分析一个算法第一步就是要确认输入以及输出，Raft 作为一个一致性算法的库，一般的使用场景是这样的：

 1. 应用层接收写入到的数据请求，向该算法库写入一个数据。
 2. 算法库返回是否写入成功。
 3. 应用层根据写入结果进行下一步操作。

作为工业应用的 Raft 库，实现相对更复杂一些，可能存在一下问题：

 1. 写入的数据，可能是集群状态变更的数据，Raft 库在执行写入这类数据之后，需要返回新的状态给应用层。
 2. Raft 库中的数据不可能一直以日志的形式存在，这样导致数据越来越大，所以有可能被压缩成快照 (snapshot) 的数据形式，这样需要返回这部分快照数据。
 3. 由于 etcd 的 Raft 库不包括持久化数据存储的模块，而是由应用层自己来实现，所以需要返回在某次写入成功之后，哪些数据可能进行持久化保存了。
 4. 同样的，etcd 的 Raft 库也没有自己实现网络传输，所以同样需要返回哪些数据需要进行网络传输给集群中的其他节点。

我们首先看到 raft/node.go 的 Ready 结构体，其中包含以下成员：

| 名称 | 类型  | 作用 |
|--|--|--|
| SoftState | SoftState  | 软状态，软状态保存易变并且不需要保存在 WAL 日志中，其中包括了集群的 leader、节点的当前状态 |
| HardState | HardState | 硬状态，与软状态相反，需要写入持久化存储中，包括了节点当前的 Term、Vote、Commit 信息 |
| Entries | []pb.Entry | 需要写入持久化存储中的日志数据 |
| Snapshot | pb.Snapshot  | 需要写入持久化存储的快照数据 |
|  CommitedEntries | []pb.Entry | 需要写入到状态机中的数据，这些数据之前已经被保存到持久化存储中了 |
| Messages | []pb.Message | 在 entries 被写入到持久化存储中以后，需要发送出去的数据 |

应用层在写入一段数据之后，Raft 库将返回一个 Ready 结构体，其中的某些字段可能是空的，毕竟不是每次改动都会导致 Ready 结构体中的成员都发生变化，此时需要使用方根据具体的情况，拿到其中需要且不为空的数据成员进行操作。

在 etcd 项目中，提供了一个使用 Raft 库的实现简单 KV 存储实验的例子，在 contrib/raftexample 目录中，我们结合这个实验来分析下如何使用 etcd 的 Raft 库。

raft 对外提供一个 Node 的 interface，其中 raft/node.go 中 node 结构的实现，是应用层直接交互的结构体，我们看看 Node 接口需要实现的函数作用：

|函数| 作用 |
|--|--|
| Tick  |  应用层每次触发心跳的时候需要调用这个函数，这个函数会驱动 raft 的一些操作比如选举等。心跳的单位是多少由应用层自己决定，只要保证是恒定时间内都会调用一次就好  |
| Compaign | 调用该函数将驱动节点进入候选人状态，从而选举竞争成为 leader |
| Propose | 提议写入数据到日志中，可能会返回错误 |
| ProposeConfChange | 提交配置变更|
| Step | 将消息 msg 灌入状态机里面 |
| Ready | 这个函数将返回 Ready 的 channel，应用层需要关注这个 channel, 当发生变更时需要将其中的数据进行操作|
| Advance |  Advance 函数是当使用者已经将上一次 Ready 的数据处理之后，调用该函数可以进行下一步操作|

说完这些函数之后，我们来看看 raftexample 处理流程，首先在 main.go 中创建了两个通道 (channel)

 1. proposeC: 用于提交写入的数据。
 2. confChange:  用于提交配置改动数据。

然后启动如下核心协程：

 1. 启动 HTTP 服务器，用于接收用户的请求数据，最终会将用户请求的数据写入上述两个通道 proposeC 和 confChangeC 两个 channel 中。
 2. 启动 raftNode 结构体，该结构体中有上述 raft/node 中的 node 结构体，这里通过该结构体实现的 Node 接口与 raft 库进行交互。同时, raftNode 还会启动协程监听前面的两个 channel，收到数据之后通过 Node 接口的函数调用 raft 库中对应的接口。

现在整个交互流程就梳理清楚了：HTTP 服务器负责接收用户数据，之后写入到两个核心的 channel 中，然后 raftNode 负责监听这两个 channel：

 1. 如果收到 proposeC channel 的消息，说明有数据提交，则调用 Node.Propose 函数进行数据的提交。
 2. 如果收到 confChangeC channel 的消息，说明有配置变更，则调用 Node.ProposeConfChange 函数进行配置变更。
 3. 设置一个定时器 tick，每次定时器到时间时，调用 Node.Tick 函数。
 4. 监听 Node.Ready 函数返回的 Ready 结构体 channel，有数据变更时根据 Ready 结构体的不同数据类型进行相应的操作，完成了之后需要调用 Node.Advance 函数进行收尾。

#### Ectd-Raft 库代码结构以及核心的数据结构

上面我们说了怎么与 etcd-raft 库交互，现在我们来详细看下库里面的代码组织。

我们先来梳理一下 raft 目录下核心的结构体和接口，以及它们的作用：

| 结构体/接口 | 所在文件 | 作用 |
|--|--|--|
| Node 接口 | node.go | 提供 raft 库与外界交互的接口 |
| node | node.go | 实现 Node 接口 |
| Config |  raft.go | raft 算法的核心实现 |
| ReadState | read_only.go | 线性一致性读相关 |
| readOnly | read_only.go | 线性一致性读相关 |
| raftLog | log.go | 实现 raft 日志操作 |
| Progress | progress.go | 该结构体用于在 leader 中保存每个 follower 的状态信息，leader 将利用这些信息决定发送给节点的日志 |
| Storage | storage.go | 提供存储接口，应用层可以按照自己的需求实现该接口 |
| unstable | log_unstable.go | 用来保存还没有持久化的数据 |
我们接下来一个个详细分析：

**unstable**

unstable 数据结构用于保存还没有被用户持久化的数，其中包含两个部分，前半部分是快照数据，后半部分是日志条目组成的数组 entries，另外 unstable.offset 成员保存的是 entries 数组中的第一条数据在 raft 日志中的索引，即第 i 条 entries 数组数据在 raft 日志中的索引为 i + unstable.offset。

接下来就是 unstable 各个函数了，我们下面逐一解释。

 - maybeFirstIndex：返回 unstable 数据的第一条数据索引。因为只有快照数据在最前面，因此这个函数只有当快照数据存在的时候才能拿到第一条数据索引，其他情况是拿不到的。
- maybeTerm：这个函数根据传入的日志数据索引，得到这个日志对应的任期号。前面已经提过，unstable.offset 是快照数据和 entries 数组的分界线，因为在这个函数中，会区分传入的参数与 offset 的大小关系，小于 offset 的情况下在快照数据中查询，否则就在 entries 数组中查询了。
- stableTo：该函数传入一个索引号 i 和任期号 t，表示应用层已经将这个索引之前的数据进行持久化了，此时 unstable 要做的事情就是在自己的数据中查询，只有在满足任期号相同以及 i 大于等于 offset 的情况下，可以将 entries 中的数据进行缩容，将 i 之前的数据删除。
- stableSnapTo：该函数传入一个索引 i，用于告诉 unstable，索引 i 对应的快照数据已经被应用层持久化了，如果这个索引与当前快照数据对应的上，那么快照数据就可以被置空了。
- restore：从快照数据中恢复，此时 unstable 将保存快照数据，同时将 offset 成员设置成这个快照数据索引的下一位。
- truncateAndAppend：传入日志条目数组，这段数据将添加到 entries 数组中。但是需要注意的是，传入的数据跟现有的 entries 数据可能有重合的部分，所以需要根据 unstable.offset 与传入数据的索引大小关系进行处理，有些数据可能会被截断。
- slice：返回索引范围在 [lo-u.offset : hi-u.offset] 之间的数据。
- mustCheckOutOfBounds：检查传入的数据索引范围是否合理。

**Storage 接口**

Storage 接口，提供了存储持久化日志相关的接口操作。其提供出来的接口函数说明如下。

- InitialState() (pb.HardState, pb.ConfState, error)：返回当前的初始状态，其中包括硬状态（HardState）以及配置（里面存储了集群中有哪些节点）。

- Entries(lo, hi, maxSize uint64) ([]pb.Entry, error)：传入起始和结束索引值，以及最大的尺寸，返回索引范围在这个传入范围以内并且不超过大小的日志条目数组。

- Term(i uint64) (uint64, error)：传入日志索引 i，返回这条日志对应的任期号。找不到的情况下 error 返回值不为空，其中当返回 ErrCompacted 表示传入的索引数据已经找不到，说明已经被压缩成快照数据了；返回 ErrUnavailable ：表示传入的索引值大于当前的最大索引。
- LastIndex() (uint64, error)：返回最后一条数据的索引。
- FirstIndex() (uint64, error)：返回第一条数据的索引。
- Snapshot() (pb.Snapshot, error)：返回最近的快照数据。

接下来看看实现了 Storage 接口的 MemoryStorage 结构体的实现，其成员主要包括以下几个部分：

- hardState pb.HardState：存储硬状态。
- snapshot pb.Snapshot：存储快照数据。
- ents []pb.Entry：存储紧跟着快照数据的日志条目数组，即 ents[i]保存的日志数据索引位置为 i + snapshot.Metadata.Index。

**raftLog 的实现**

有了以上的介绍 unstable、Storage 的准备之后，下面可以来介绍 raftLog 的实现，这个结构体承担了 raft 日志相关的操作。

raftLog 由以下成员组成。

- storage Storage：前面提到的存放已经持久化数据的 Storage 接口。
- unstable unstable：前面分析过的 unstable 结构体，用于保存应用层还没有持久化的数据。
- committed uint64：保存当前提交的日志数据索引。
- applied uint64：保存当前传入状态机的数据最高索引。

需要说明的是，一条日志数据，首先需要被提交（committed）成功，然后才能被应用（applied）到状态机中。因此，以下不等式一直成立：applied <= committed。

raftLog 结构体中，几部分数据的排列如下图所示。

![在这里插入图片描述](https://images.gitbook.cn/2f662f80-23b9-11eb-9031-a33a0f110c14)

这个数据排布的情况，可以从 raftLog 的初始化函数中看出来：
```
func newLog(storage Storage, logger Logger) *raftLog {
	if storage == nil {
		log.Panic("storage must not be nil")
	}
	log := &raftLog{
		storage: storage,
		logger:  logger,
	}
	firstIndex, err := storage.FirstIndex()
	if err != nil {
		panic(err) // TODO(bdarnell)
	}
	lastIndex, err := storage.LastIndex()
	if err != nil {
		panic(err) // TODO(bdarnell)
	}
	// offset 从持久化之后的最后一个 index 的下一个开始
	log.unstable.offset = lastIndex + 1
	log.unstable.logger = logger
	// Initialize our committed and applied pointers to the time of the last compaction.
	// committed 和 applied 从持久化的第一个 index 的前一个开始
	log.committed = firstIndex - 1
	log.applied = firstIndex - 1
	return log
}
```

在这里：

- firstIndex：该值取自 storage.FirstIndex()，可以从 MemoryStorage 的实现看到，该值是 MemoryStorage.ents 数组的第一个数据索引，也就是 MemoryStorage 结构体中快照数据与日志条目数据的分界线。
- lastIndex：该值取自 storage.LastIndex()，可以从 MemoryStorage 的实现看到，该值是 MemoryStorage.ents 数组的最后一个数据索引。
- unstable.offset：该值为 lastIndex 索引的下一个位置。
- committed、applied：在初始的情况下，这两个值是 firstIndex 的上一个索引位置，这是因为在 firstIndex 之前的数据既然已经是持久化数据了，说明都是已经被提交成功的数据了。

因此，从这里的代码分析可以看出，raftLog 的两部分，持久化存储和非持久化存储，它们之间的分界线就是 lastIndex ，在此之前都是 Storage 管理的已经持久化的数据，而在此之后都是 unstable 管理的还没有持久化的数据。

以上分析中还有一个疑问，为什么并没有初始化 unstable.snapshot 成员，也就是 unstable 结构体的快照数据？原因在于，上面这个是初始化函数，也就是节点刚启动的时候调用来初始化存储状态的函数，而 unstable.snapshot 数据，是在启动之后同步数据的过程中，如果需要同步快照数据时才会去进行赋值修改的数据，因此在这里并没有对它进行操作的地方。

**raft 消息结构体**

大体而言，raft 算法本质上是一个大的状态机，任何的操作例如选举、提交数据等，最后的操作一定是封装成一个消息结构体，输入到 raft 算法库的状态机中。

在 raft/raftpb/raft.proto 文件中，定义了 raft 算法中传输消息的结构体。熟悉 raft 论文的都知道，raft 算法其实由好几个协议组成，但是在这里，统一定义在了 Message 这个结构体之中，以下总结了该结构体的成员用途。

| 成员 | 类型 | 作用 |
|--|--| --|
| type | MessageType  | 消息类型|
|to |uint64 | 消息接收者的节点 ID|
| from |	uint64	| 消息发送者的节点 ID |
| term |	uint64 | 任期 ID |
| logTerm |	uint64 | 日志所处的任期 ID |
| index |	uint64 |	日志索引 ID，用于节点向 leader 汇报自己已经 commit 的日志数据 ID |
|entries	|Entry	|日志条目数组|
|commit	|uint64|	提交日志索引|
|snapshot|Snapshot	|快照数据|
|reject	|bool|是否拒绝|
|rejectHint|	uint64|	拒绝同步日志请求时返回的当前节点日志 ID，用于被拒绝方快速定位到下一次合适的同步日志位置|
|context|	bytes	|上下文数据|

由于这个 Message 结构体，全部将 raft 协议相关的数据都定义在了一起，有些协议不是用到其中的全部数据。

**MsgHup 消息**

| 成员 | 类型	 |作用|
|--|--|--|
|  type|  MsgHup|不用于节点间通信，仅用于发送给本节点让本节点进行选举 |	
|to	|uint64	|消息接收者的节点 ID|
|from	|uint64	|本节点 ID|

**MsgBeat 消息**

| 成员 | 类型 |作用|
|--|--|--|
|  type| MsgBeat | 不用于节点间通信，仅用于 leader 节点在 heartbeat 定时器到期时向集群中其他节点发送心跳消息|		
|to|uint64	|消息接收者的节点 ID|
|from|uint64	 |本节点 ID|

**MsgProp 消息**

| 成员 |  类型|作用|
|--|--|--|
|  type| MsgProp |raft 库使用者提议（propose）数据 |
|to |uint64	|消息接收者的节点 ID |
|from|	uint64	|本节点 ID|
|entries|	Entry	|日志条目数组|

raft 库的使用者向 raft 库 propose 数据时，最后会封装成这个类型的消息来进行提交，不同类型的节点处理还不尽相同。

candidate: 由于 candidate 节点没有处理 propose 数据的责任，所以忽略这类型消息。

follower: 首先会检查集群内是否有 leader 存在，如果当前没有 leader 存在说明还在选举过程中，这种情况忽略这类消息；否则转发给 leader 处理。

leader: leader 的处理在 leader 的状态机函数针对 MsgProp 这种 case 的处理下，大体如下。

 1. 检查 entries 数组是否没有数据，这是一个保护性检查。
 2. 检查本节点是否还在集群之中，如果已经不在了则直接返回不进行下一步处理。什么情况下会出现一个 leader 节点发现自己不存在集群之中了？这种情况出现在本节点已经通过配置变化被移除出了集群的场景。
 3. 检查 raft.leadTransferee 字段，当这个字段不为 0 时说明正在进行 leader 迁移操作，这种情况下不允许提交数据变更操作，因此此时也是直接返回的。
 4. 检查消息的 entries 数组，看其中是否带有配置变更的数据。如果其中带有数据变更而 raft.pendingConf 为 true，说明当前有未提交的配置更操作数据，根据 raft 论文，每次不同同时进行一次以上的配置变更，因此这里会将 entries 数组中的配置变更数据置为空数据。
 5. 到了这里可以进行真正的数据 propose 操作了，将调用 raft 算法库的日志模块写入数据，根据返回的情况向其他节点广播消息。

**MsgApp/MsgSnap 消息**

- MsgApp 消息

| 成员 |类型  | 作用|
|--|--|--|
| type | MsgApp |用于 leader 向集群中其他节点同步数据的消息 |		
|to	|uint64	|消息接收者的节点 ID|
|from|	uint64|	本节点 ID|
|entries|	Entry	|日志条目数组|
|logTerm|	uint64	|日志所处的任期 ID|
|index|	uint64|	索引 ID|

- MsgSnap 消息

| 成员 |  类型| 作用|
|--|--|--|
| type |  MsgSnap|用于 leader 向 follower 同步数据用的快照消息 |	
|to	|uint64	|消息接收者的节点 ID|
|from|uint64	|本节点 ID|
|snapshot|Snapshot	|快照数据|

如果说前面的 MsgProp 消息是集群中的节点向 leader 转发用户提交的数据，那么 MsgApp 消息就是相反的，是 leader 节点用于向集群中其他节点同步数据的。

在这里把 MsgSnap 消息和 MsgApp 消息放在一起，是因为 MsgSnap 消息做的事情其实跟前面提到的 MsgApp 消息是一样的：都是用于 leader 向 follower 同步数据。实际上对于 leader 而言，向某个节点同步数据这个操作，都封装在 raft.sendAppend 函数中，至于具体用的哪种消息类型由这个函数内部实现。

那么，什么情况下会用到快照数据来同步呢？raft 算法中，任何的数据要提交成功，首先 leader 会在本地写一份日志，再广播出去给集群的其他节点，只有在超过半数以上的节点同意，leader 才能进行提交操作，这一个流程在前面讲解 MsgAppResp 消息流程时做了解释。

但是，如果这个日志文件不停的增长，显然是不能接受的。因此，在某些时刻，节点会将日志数据进行压缩处理，就是把当前的数据写入到一个快照文件中。而 leader 在向某一个节点进行数据同步时，是根据该节点上的日志记录进行数据同步的。

比方说，leader 上已经有最大索引为 10 的日志数据，而节点 A 的日志索引是 2，那么 leader 将从 3 开始向节点 A 同步数据。

但是如果前面的数据已经进行了压缩处理，转换成了快照数据，而压缩后的快照数据实际上已经没有日志索引相关的信息了。这时候只能将快照数据全部同步给节点了。还是以前面的流程为例，假如 leader 上日志索引为 7 之前的数据都已经被压缩成了快照数据，那么这部分数据在同步时是需要整份传输过去的，只有当同步完成节点赶上了 leader 上的日志进度时，才开始正常的日志同步流程。 而同步数据时，需要区分两种情况：

**MsgAppResp 消息**

| 成员 | 类型 | 作用|
|--|--|--|
| type |MsgAppResp  | 集群中其他节点针对 leader 的 MsgApp/MsgSnap 消息的应答消息|
|to	|uint64	|消息接收者的节点 ID|
|from	|uint64	|本节点 ID|
|index|	uint64	|日志索引 ID，用于节点向 leader 汇报自己已经 commit 的日志数据 ID|
|reject	|bool|	是否拒绝同步日志的请求|
|rejectHint|	uint64|	拒绝同步日志请求时返回的当前节点日志 ID，用于被拒绝方快速定位到下一次合适的同步日志位置|


在节点收到 leader 的 MsgApp/MsgSnap 消息时，可能出现 leader 上的数据与自身节点数据不一致的情况，这种情况下会返回 reject 为 true 的 MsgAppResp 消息，同时 rejectHint 字段是本节点 raft 最后一条日志的索引 ID。

而 index 字段则返回的是当前节点的日志索引 ID，用于向 leader 汇报自己已经 commit 的日志数据 ID，这样 leader 就知道下一次同步数据给这个节点时，从哪条日志数据继续同步了。

leader 节点在收到 MsgAppResp 消息的处理流程大体如下（stepLeader 函数中 MsgAppResp case 的处理流程）。

首先，收到节点的 MsgAppResp 消息，说明该节点是活跃的，因此保存节点状态的 RecentActive 成员置为 true。

接下来，再根据 msg.Reject 的返回值，即节点是否拒绝了这次数据同步，来区分两种情况进行处理。如果 msg.Reject 为 true，说明节点拒绝了前面的 MsgApp/MsgSnap 消息，根据 msg.RejectHint 成员回退 leader 上保存的关于该节点的日志记录状态。比如 leader 前面认为从日志索引为 10 的位置开始向节点 A 同步数据，但是节点 A 拒绝了这次数据同步，同时返回 RejectHint 为 2，说明节点 A 告知 leader 在它上面保存的最大日志索引 ID 为 2，这样下一次 leader 就可以直接从索引为 2 的日志数据开始同步数据到节点 A。而如果没有这个 RejectHint 成员，leader 只能在每次被拒绝数据同步后都递减 1 进行下一次数据同步，显然这样是低效的。

因为上面节点拒绝了这次数据同步，所以节点的状态可能存在一些异常，此时如果 leader 上保存的节点状态为 ProgressStateReplicate，那么将切换到 ProgressStateProbe 状态（关于这几种状态，下面会谈到）。

前面已经按照 msg.RejectHint 修改了 leader 上关于该节点日志状态的索引数据，接着再次尝试按照这个新的索引数据向该节点再次同步数据。

**msg.Reject 为 false 的情况**

这种情况说明这个节点通过了 leader 的这一次数据同步请求，这种情况下根据 msg.Index 来判断在 leader 中保存的该节点日志数据索引是否发生了更新，如果发生了更新那么就说明这个节点通过了新的数据，这种情况下会做以下的几个操作。

**修改节点状态**

如果该节点之前在 ProgressStateProbe 状态，说明之前处于探测状态，此时可以切换到 ProgressStateReplicate，开始正常的接收 leader 的同步数据了。

如果之前处于 ProgressStateSnapshot 状态，即还在同步副本，说明节点之前可能落后 leader 数据比较多才采用了接收副本的状态。这里还需要多做一点解释，因为在节点落后 leader 数据很多的情况下，可能 leader 会多次通过 snapshot 同步数据给节点，而当 pr.Match >= pr.PendingSnapshot 的时候，说明通过快照来同步数据的流程完成了，这时可以进入正常的接收同步数据状态了，这就是函数 Progress.needSnapshotAbort 要做的判断。

如果之前处于 ProgressStateReplicate 状态，此时可以修改 leader 关于这个节点的滑动窗口索引，释放掉这部分数据索引，好让节点可以接收新的数据了。关于这个滑动窗口设计，见下面详细解释。

判断是否有新的数据可以提交（commit）了。因为 raft 的提交数据的流程是这样的：首先节点将数据提议（propose）给 leader，leader 在将数据写入到自己的日志成功之后，再通过 MsgApp 把这些提议的数据广播给集群中的其他节点，在某一条日志数据收到超过半数（qurom）的节点同意之后，才认为是可以提交（commit）的。因此每次 leader 节点在收到一条 MsgAppResp 类型消息，同时 msg.Reject 又是 false 的情况下，都需要去检查当前有哪些日志是超过半数的节点同意的，再将这些可以提交（commit）的数据广播出去。而在没有数据可以提交的情况下，如果之前节点处于暂停状态，那么将继续向该节点同步数据。

最后还要做一个跟 leader 迁移相关的操作。如果该消息节点是准备迁移过去的新 leader 节点（raft.leadTransferee == msg.From），而且此时该节点上的 Match 索引已经跟旧的 leader 的日志最大索引一致，说明新旧节点的日志数据已经同步，可以正式进行集群 leader 迁移操作了。

MsgVote/MsgPreVote 消息以及 MsgVoteResp/MsgPreVoteResp 消息
这里把这四种消息放在一起了，因为不论是 Vote 还是 PreVote 流程，其请求和应答时传输的数据都是一样的。

**请求数据**

| 成员 | 类型 | 作用|
|--|--|--|
| type |  MsgVote/MsgPreVote|节点投票给自己以进行新一轮的选举 |
|to	|uint64	|消息接收者的节点 ID|
|from	|uint64	|本节点 ID|
|term	|uint64|	任期 ID|
|index	|uint64	|日志索引 ID，用于节点向 leader 汇报自己已经 commit 的日志数据 ID|
|logTerm	|uint64|	日志所处的任期 ID|
|context|	bytes	|上下文数据|

应答数据。

|成员  | 类型 |作用|
|--|--|--|
| type | MsgVoteResp/MsgPreVoteResp	 |投票应答消息 |
|to	|uint64	|消息接收者的节点 ID|
|from|	uint64	|本节点 ID|
|reject|	bool	|是否拒绝|

节点调用 raft.campaign 函数进行投票给自己进行一次新的选举，其中的参数 CampaignType 有以下几种类型：

- campaignPreElection：对应 PreVote 的场景。
- campaignElection：正常的选举场景。
- campaignTransfer：由于 leader 迁移发生的选举。如果是这种类型的选举，那么 msg.Context 字段保存的是 “CampaignTransfer” 字符串，这种情况下会强制进行 leader 的迁移。MsgVote 还需要带上几个与本节点日志相关的数据（Index、LogTerm），因为 raft 算法要求，一个节点要成为 leader 的一个必要条件之一就是这个节点上的日志数据是最新的。

**PreVote**

这里需要特别解释一下 PreVote 的场景。

考虑到一种情况：当出现网络分区的时候，A、B、C、D、E 五个节点被划分成了两个网络分区，A、B、C 组成的分区和 D、E 组成的分区，其中的 D 节点，如果在选举超时到来时，都没有收到来自 leader 节点 A 的消息（因为网络已经分区），那么 D 节点认为需要开始一次新的选举了。

正常的情况下，节点 D 应该把自己的任期号 term 递增 1，然后发起一次新的选举。由于网络分区的存在，节点 D 肯定不会获得超过半数以上的的投票，因为 A、B、C 三个节点组成的分区不会收到它的消息，这会导致节点 D 不停的由于选举超时而开始一次新的选举，而每次选举又会递增任期号。

在网络分区还没恢复的情况下，这样做问题不大。但是当网络分区恢复时，由于节点 D 的任期号大于当前 leader 节点的任期号，这会导致集群进行一次新的选举，即使节点 D 肯定不会获得选举成功的情况下（因为节点 D 的日志落后当前集群太多，不能赢得选举成功）。

为了避免这种无意义的选举流程，节点可以有一种 PreVote 的状态，在这种状态下，想要参与选举的节点会首先连接集群的其他节点，只有在超过半数以上的节点连接成功时，才能真正发起一次新的选举。

所以，在 PreVote 状态下发起选举时，并不会导致节点本身的任期号递增 1，而只有在进行正常选举时才会将任期号加 1 进行选举。

**MsgVote/MsgPreVote 的处理流程**

来看看节点对于投票消息的处理，这些处理有两处，但是都在 raft.Step 函数中。

首先该函数会判断 msg.Term 是否大于本节点的 Term，如果消息的任期号更大则说明是一次新的选举。这种情况下将根据 msg.Context 是否等于 “CampaignTransfer” 字符串来确定是不是一次由于 leader 迁移导致的强制选举过程。同时也会根据当前的 electionElapsed 是否小于 electionTimeout 来确定是否还在租约期以内。如果既不是强制 leader 选举又在租约期以内，那么节点将忽略该消息的处理，在论文 4.2.3 部分论述这样做的原因，是为了避免已经离开集群的节点在不知道自己已经不在集群内的情况下，仍然频繁的向集群内节点发起选举导致耗时在这种无效的选举流程中。如果以上检查流程通过了，说明可以进行选举了，如果消息类型还不是 MsgPreVote 类型，那么此时节点会切换到 follower 状态且认为发送消息过来的节点 msg.From 是新的 leader。

```
case m.Term > r.Term:
// 消息的 Term 大于节点当前的 Term
lead := m.From
if m.Type == pb.MsgVote || m.Type == pb.MsgPreVote {
	// 如果收到的是投票类消息
	// 当 context 为 campaignTransfer 时表示强制要求进行竞选
	force := bytes.Equal(m.Context, []byte(campaignTransfer))
	// 是否在租约期以内
	inLease := r.checkQuorum && r.lead != None && r.electionElapsed < r.electionTimeout
	if !force && inLease {
		// 如果非强制，而且又在租约期以内，就不做任何处理
		// 非强制又在租约期内可以忽略选举消息，见论文的 4.2.3，这是为了阻止已经离开集群的节点再次发起投票请求
		// If a server receives a RequestVote request within the minimum election timeout
		// of hearing from a current leader, it does not update its term or grant its vote
		r.logger.Infof("%x [logterm: %d, index: %d, vote: %x] ignored %s from %x [logterm: %d, index: %d] at term %d: lease is not expired (remaining ticks: %d)",
			r.id, r.raftLog.lastTerm(), r.raftLog.lastIndex(), r.Vote, m.Type, m.From, m.LogTerm, m.Index, r.Term, r.electionTimeout-r.electionElapsed)
		return nil
	}
	// 否则将 lead 置为空
	lead = None
}
switch {
// 注意 Go 的 switch case 不做处理的话是不会默认走到 default 情况的
case m.Type == pb.MsgPreVote:
	// Never change our term in response to a PreVote
	// 在应答一个 prevote 消息时不对任期 term 做修改
case m.Type == pb.MsgPreVoteResp && !m.Reject:
	// We send pre-vote requests with a term in our future. If the
	// pre-vote is granted, we will increment our term when we get a
	// quorum. If it is not, the term comes from the node that
	// rejected our vote so we should become a follower at the new
	// term.
default:
	r.logger.Infof("%x [term: %d] received a %s message with higher term from %x [term: %d]",
		r.id, r.Term, m.Type, m.From, m.Term)
	// 变成 follower 状态
	r.becomeFollower(m.Term, lead)
}
```

在 raft.Step 函数的后面，会判断消息类型是 MsgVote 或者 MsgPreVote 来进一步进行处理。其判断条件是以下两个条件同时成立：

当前没有给任何节点进行过投票（r.Vote == None ），或者消息的任期号更大（m.Term > r.Term ），或者是之前已经投过票的节点（r.Vote == m.From)）。这个条件是检查是否可以还能给该节点投票。

同时该节点的日志数据是最新的（r.raftLog.isUpToDate(m.Index, m.LogTerm) ）。这个条件是检查这个节点上的日志数据是否足够的新。 只有在满足以上两个条件的情况下，节点才投票给这个消息节点，将修改 raft.Vote 为消息发送者 ID。如果不满足条件，将应答 msg.Reject=true ，拒绝该节点的投票消息。

```
case pb.MsgVote, pb.MsgPreVote:
// 收到投票类的消息
// The m.Term > r.Term clause is for MsgPreVote. For MsgVote m.Term should
// always equal r.Term.
if (r.Vote == None || m.Term > r.Term || r.Vote == m.From) && r.raftLog.isUpToDate(m.Index, m.LogTerm) {
	// 如果当前没有给任何节点投票（r.Vote == None）或者投票的节点 term 大于本节点的（m.Term > r.Term）
	// 或者是之前已经投票的节点（r.Vote == m.From）
	// 同时还满足该节点的消息是最新的（r.raftLog.isUpToDate(m.Index, m.LogTerm)），那么就接收这个节点的投票
	r.logger.Infof("%x [logterm: %d, index: %d, vote: %x] cast %s for %x [logterm: %d, index: %d] at term %d",
		r.id, r.raftLog.lastTerm(), r.raftLog.lastIndex(), r.Vote, m.Type, m.From, m.LogTerm, m.Index, r.Term)
	r.send(pb.Message{To: m.From, Type: voteRespMsgType(m.Type)})
	if m.Type == pb.MsgVote {
		// Only record real votes.
		// 保存下来给哪个节点投票了
		r.electionElapsed = 0
		r.Vote = m.From
	}
} else {
	// 否则拒绝投票
	r.logger.Infof("%x [logterm: %d, index: %d, vote: %x] rejected %s from %x [logterm: %d, index: %d] at term %d",
		r.id, r.raftLog.lastTerm(), r.raftLog.lastIndex(), r.Vote, m.Type, m.From, m.LogTerm, m.Index, r.Term)
	r.send(pb.Message{To: m.From, Type: voteRespMsgType(m.Type), Reject: true})
}
```

**MsgVoteResp/MsgPreVoteResp 的处理流程**

来看节点收到投票应答数据之后的处理。

节点调用 raft.poll 函数，其中传入 msg.Reject 参数表示发送者是否同意这次选举，根据这些来计算当前集群中有多少节点给这次选举投了同意票。

如果有半数的节点同意了，如果选举类型是 PreVote，那么进行 Vote 状态正式进行一轮选举；否则该节点就成为了新的 leader，调用 raft.becomeLeader 函数切换状态，然后开始同步日志数据给集群中其他节点了。

而如果半数以上的节点没有同意，那么重新切换到 follower 状态。
```
case myVoteRespType:
	// 计算当前集群中有多少节点给自己投了票
	gr := r.poll(m.From, m.Type, !m.Reject)
	r.logger.Infof("%x [quorum:%d] has received %d %s votes and %d vote rejections", r.id, r.quorum(), gr, m.Type, len(r.votes)-gr)
	switch r.quorum() {
	case gr:	// 如果进行投票的节点数量正好是半数以上节点数量
		if r.state == StatePreCandidate {
			r.campaign(campaignElection)
		} else {
			// 变成 leader
			r.becomeLeader()
			r.bcastAppend()
		}
	case len(r.votes) - gr:	// 如果是半数以上节点拒绝了投票
		// 变成 follower
		r.becomeFollower(r.Term, None)
	}
```

**MsgHeartbeat/MsgHeartbeatResp 消息**

心跳请求消息。

| 成员 | 类型 | 作用 |
|--|--|--|
|  type | MsgHeartbeat  | 用于 leader 向 follower 发送心跳消息 |
| to |	uint64 |	消息接收者的节点 ID |
| from | uint64 | 本节点 ID |
| commit |	uint64 | 提交日志索引 |
| context |	bytes | 上下文数据，在这里保存一致性读相关的数据 |

心跳请求应答消息。
| 成员 | 类型 | 作用 |
|--|--|--|
|  type| MsgHeartbeatResp | 用于 follower 向 leader 应答心跳消息|
|to|	uint64 |	消息接收者的节点 ID|
|from |	uint64 |	本节点 ID |
|context |	bytes	|上下文数据，在这里保存一致性读相关的数据|

leader 中会定时向集群中其他节点发送心跳消息，该消息的作用除了探测节点的存活情况之外，还包括：

 1. commit 成员：leader 选择 min[节点上的 Match，leader 日志最大提交索引]，用于告知节点哪些日志可以进行提交（commit）。
 2. context：与线性一致性读相关，后面会进行解释。

**MsgUnreachable 消息**

|  成员 | 类型 | 作用  |
|--|--| --|
|  type| MsgUnreachable | 用于应用层向 raft 库汇报某个节点当前已不可达|
|to | uint64	|消息接收者的节点 ID |
|from | uint64 |不可用的节点 ID |

仅 leader 才处理这类消息，leader 如果判断该节点此时处于正常接收数据的状态（ProgressStateReplicate），那么就切换到探测状态。

**MsgSnapStatus 消息**
| 成员 | 类型 |作用 |
|--|--|--|
|type  |MsgSnapStatus  |用于应用层向 raft 库汇报某个节点当前接收快照状态 |
|to|uint64	|消息接收者的节点 ID|
|from|	uint64	|节点 ID|
|reject	|bool	|是否拒绝|

仅 leader 处理这类消息：

 1. 如果 reject 为 false：表示接收快照成功，将切换该节点状态到探测状态。
 2. 否则接收失败。

**MsgCheckQuorum 消息**

| 成员 |  类型| 作用|
|--|--|--|
|type	|MsgCheckQuorum	|用于 leader 检查集群可用性的消息|
|to|	uint64	|消息接收者的节点 ID|
|from|	uint64	|节点 ID|

leader 的定时器函数，在超过选举时间时，如果当前打开了 raft.checkQuorum 开关，那么 leader 将给自己发送一条 MsgCheckQuorum 消息，对该消息的处理是：检查集群中所有节点的状态，如果超过半数的节点都不活跃了，那么 leader 也切换到 follower 状态。

**MsgTransferLeader 消息**

| 成员 |类型  |作用|
|--|--|--|
|  type|MsgTransferLeader  |用于迁移 leader |		
|to|	uint64	|消息接收者的节点 ID|
|from	|uint64|	注意这里不是发送者的 ID 了，而是准备迁移过去成为新 leader 的节点 ID|

这类消息 follower 将转发给 leader 处理，因为 follower  并没有修改集群配置状态的权限。

leader 在收到这类消息时，是以下的处理流程。

如果当前的 raft.leadTransferee 成员不为空，说明有正在进行的 leader 迁移流程。此时会判断是否与这次迁移是同样的新 leader ID，如果是则忽略该消息直接返回；否则将终止前面还没有完毕的迁移流程。

如果这次迁移过去的新节点，就是当前的 leader ID，也直接返回不进行处理。

到了这一步就是正式开始这一次的迁移 leader 流程了，一个节点能成为一个集群的 leader，其必要条件是上面的日志与当前 leade r 的一样多，所以这里会判断是否满足这个条件，如果满足那么发送 MsgTimeoutNow 消息给新的 leader 通知该节点进行 leader 迁移，否则就先进行日志同步操作让新的 leader 追上旧 leader 的日志数据。
```
case pb.MsgTransferLeader:
leadTransferee := m.From
lastLeadTransferee := r.leadTransferee
if lastLeadTransferee != None {
// 判断是否已经有相同节点的 leader 转让流程在进行中
if lastLeadTransferee == leadTransferee {
  r.logger.Infof("%x [term %d] transfer leadership to %x is in progress, ignores request to same node %x",
    r.id, r.Term, leadTransferee, leadTransferee)
  // 如果是，直接返回
  return
}
	// 否则中断之前的转让流程
	r.abortLeaderTransfer()
	r.logger.Infof("%x [term %d] abort previous transferring leadership to %x", r.id, r.Term, lastLeadTransferee)
}
// 判断是否转让过来的 leader 是否本节点，如果是也直接返回，因为本节点已经是 leader 了
if leadTransferee == r.id {
	r.logger.Debugf("%x is already leader. Ignored transferring leadership to self", r.id)
	return
}
	// Transfer leadership to third party.
	r.logger.Infof("%x [term %d] starts to transfer leadership to %x", r.id, r.Term, leadTransferee)
	// Transfer leadership should be finished in one electionTimeout, so reset r.electionElapsed.
	r.electionElapsed = 0
	r.leadTransferee = leadTransferee
	if pr.Match == r.raftLog.lastIndex() {
	// 如果日志已经匹配了，那么就发送 timeoutnow 协议过去
	r.sendTimeoutNow(leadTransferee)
	r.logger.Infof("%x sends MsgTimeoutNow to %x immediately as %x already has up-to-date log", r.id, leadTransferee, leadTransferee)
} else {
// 否则继续追加日志
	r.sendAppend(leadTransferee)
}

```

**MsgTimeoutNow 消息**

|  成员| 类型 | 作用|
|--|--|--|
| type | MsgTimeoutNow |leader 迁移时，当新旧 leader 的日志数据同步后，旧 leader 向新 leader 发送该消息通知可以进行迁移了 |
|to	|uint64	|新的 leader ID|
|from	|uint64	|旧的 leader 的节点 ID|

新的 leader 节点，在还未迁移之前仍然是 follower，在收到这条消息后，就可以进行迁移了，此时会调用前面分析 MsgVote 时说过的 campaign 函数，传入的参数是 campaignTransfer，表示这是一次由于迁移 leader 导致的选举流程。

MsgReadIndex 和 MsgReadIndexResp 消息，这两个消息一一对应，使用的成员也一样，在后面分析读一致性的时候再详细解释。

| 成员 |  类型 | 作用|
|--|--|--|
| type | MsgReadIndex |用于读一致性的消息|
|to|uint64	|接收者节点 ID |
|from|	uint64	|发送者节点 ID|
|entries|	Entry|	日志条目数组|

其中，entries 数组只会有一条数据，带上的是应用层此次请求的标识数据，在 follower 收到 MsgReadIndex 消息进行应答时，同样需要把这个数据原样带回返回给 leader，详细的线性读一致性的实现在后面展开分析。

**节点状态**

每个 raft 的节点，分为以下三种状态：

 1. candidate：候选人状态，节点切换到这个状态时，意味着将进行一次新的选举。
 2. follower：跟随者状态，节点切换到这个状态时，意味着选举结束。
 3. leader：领导者状态，所有数据提交都必须先提交到 leader 上。

每一个状态都有其对应的状态机，每次收到一条提交的数据时，都会根据其不同的状态将消息输入到不同状态的状态机中。同时，在进行 tick 操作时，每种状态对应的处理函数也是不一样的。

所以 raft 结构体中将不同的状态，及其不同的处理函数独立出来几个成员变量：

|  成员| 作用 |
|--|--|
| state | 保存当前节点状态 |
|tick 函数	|tick 函数，每个状态对应的 tick 函数不同|
|step 函数|	状态机函数，同样每个状态对应的状态机也不相同|

raft 库中提供几个成员函数 becomeCandidate、becomeFollower、becomeLeader 分别进入这几种状态的，这些函数中做的事情，概况起来就是：

 1. 切换 raft.state 成员到对应状态。
 2. 切换 raft.tick 函数到对应状态的处理函数。
 3. 切换 raft.step 函数到对应状态的状态机。

**选举流程**

raft 算法的第一步是首先选举出一个 leader 出来，在没有产生 leader 的情况下，其他数据提交等操作都无从谈起，所以这里首先从选举的流程开始谈起。

**发起选举的节点**

只有在 candidate 或者 follower 状态下的节点，才有可能发起一个选举流程，而这两种状态的节点，其对应的 tick 函数都是 raft.tickElection 函数，这个函数的主要流程是：

1. 将选举超时递增 1。
2. 当选举超时到期，同时该节点又在集群中时，说明此时可以进行一轮新的选举。此时会向本节点发送 HUP 消息，这个消息最终会走到状态机函数 raft.Step 中进行处理。
3. 明白了 raft.tickElection 函数的作用，可以来看选举流程了：

节点启动时都以 follower 状态启动，同时随机选择自己的选举超时时间。之所以每个节点随机选择自己的超时时间，是为了避免同时有两个节点同时进行选举，这种情况下会出现没有任何一个节点赢得半数以上的投票从而这一轮选举失败，继续再进行下一轮选举

在 follower 的 tick 函数 tickElection 函数中，当选举超时到时，节点向自己发送 HUP 消息。

在状态机函数 raft.Step 函数中，在收到 HUP 消息之后，节点首先判断当前有没有没有 apply 的配置变更消息，如果有就忽略该消息。其原因在于，当有配置更新的情况下不能进行选举操作，即要保证每一次集群成员变化时只能同时变化一个，不能同时有多个集群成员的状态发生变化。

否则进入 campaign 函数中进行选举：首先将任期号 +1，然后广播给其他节点选举消息，带上的其它字段包括：节点当前的最后一条日志索引（Index 字段），最后一条日志对应的任期号（LogTerm 字段），选举任期号（Term 字段，即前面已经进行+1 之后的任期号），Context 字段（目的是为了告知这一次是否是 leader 转让类需要强制进行选举的消息）。

如果在一个选举超时之内，该发起新的选举流程的节点，得到了超过半数的节点投票，那么状态就切换到 leader 状态，成为 leader 的同时，leader 将发送一条 dummy 的 append 消息，目的是为了提交该节点上在此任期之前的值（见疑问部分如何提交之前任期的值）

**收到选举消息的节点**

当收到任期号大于当前节点任期号的消息，同时该消息类型如果是选举类的消息（类型为 prevote 或者 vote）时，会做以下判断：

首先会判断一下该消息是否为强制要求进行选举的类型（context 为 campaignTransfer ，context 为这种类型时表示在进行 leader 转让，流程见下面的 leader 转让流程）

判断当前是否在租约期以内，判断的条件包括：checkQuorum 为 true，当前节点保存的 leader 不为空，没有到选举超时，前面这三个条件同时满足。

如果不是强制要求选举，同时又在租约期以内，那么就忽略该选举消息返回不进行处理，这么做是为了避免出现那些离开集群的节点，频繁发起新的选举请求（见论文 4.2.3）。

如果不是前面的忽略选举消息的情况，那么除非是 prevote 类的选举消息，在收到其他消息的情况下，该节点都切换为 followe r 状态。

此时需要针对投票类型中带来的其他字段进行处理了，需要同时满足以下两个条件：

- 只有在没有给其他节点进行过投票，或者消息的 term 任期号大于当前节点的任期号，或者之前的投票给的就是这个发出消息的节点
- 进行选举的节点，它的日志是更新的，条件为：logterm 比本节点最新日志的任期号大，在两者相同的情况下，消息的 index 大于等于当前节点最新日志的 index，即总要保证该选举节点的日志比自己的大。

只有在同时满足以上两个条件的情况下，才能同意该节点的选举，否则都会被拒绝。这么做的原因是：保证最后能胜出来当新的 leader 的节点，它上面的日志都是最新的。

**集群成员变化流程**

大原则是不能同时进行两个以上的成员变更，因为同时进行两个以上的成员变更，可能会出现集群中有两个 leader 即导致了集群分裂的情况出现。

成员变化分为以下几种情况：成员删减、leader 转让，下面分开讲解。

**一般的成员删减**

成员变化操作做为日志的特殊类型，当可以进行 commit 的情况下，各个节点拿出该消息进行节点内部的成员删减操作。

**leader 转让**

旧 leader 在接收到转让 leader 消息之后，会做如下的判断：

- a. 如果新的 leader 上的日志，已经跟当前 leader 上的日志同步了，那么发送 timeout 消息。 
- b. 否则继续发 append 消息到新的 leader 上，目的为了让其能够与旧 leader 日志同步。

当旧 leader 处于转让 leader 状态时，将停止接收新的 prop 消息，这样就避免出现在转让过程中新旧 leader 一直日志不能同步的情况。

当旧 leader 收到 append 消息应答时，如果当前处于 leader 转让状态，那么会判断新的 leader 日志是否已经与当前 leader 同步，如果是将发送 timeout 消息。

新的 leader 当收到 timeout 消息时，将使用 context 为 campaignTransfer 的选举消息发起新一轮选举，当 context 为该类型时，此时的选举是强制进行的（见前面的选举流程）。

**如何做到线性一致性？**

线性一致性（Linearizable Read）通俗来讲，就是读请求需要读到最新的已经 commit 的数据，不会读到老数据。

由于所有的 leader 和 follower 都能处理客户端的读请求，所以存在可能造成返回读出的旧数据的情况：

leader 和 follower 之间存在状态差，因为 follower 总是由 leader 同步过去的，可能会返回同步之前的数据。

如果发生了网络分区，某个 leader 实际上已经被隔离出了集群之外，但是该 leader 并不知道，如果还继续响应客户端的读请求，也可能会返回旧的数据。

因此，在接收到客户端的读请求时，需要保证返回的数据都是当前最新的。

**ReadOnlySafe 方式**

leader 在接收到读请求时，需要向集群中的超半数 server 确认自己仍然是当前的 leader，这样它返回的就是最新的数据。 

在 etcd-raft 中，为了实现 ReadOnlySafe，有如下的数据结构：

```
type ReadState struct {
  Index uint64
  RequestCtx []byte
}
```

其中：

- Index：接收到该读请求时，当前节点的 commit 索引。
- RequestCtx：客户端读请求的唯一标识。
- ReadState 结构体用于保存读请求到来时的节点状态。

```
type readIndexStatus struct {
 req pb.Message
 index uint64
 acks map[uint64]struct{}
}
```

readIndexStatus 数据结构用于追踪 leader 向 follower 发送的心跳信息，其中：

- req：保存原始的 readIndex 请求。
- index：leader 当前的 commit 日志索引。
- acks：存放该 readIndex 请求有哪些节点进行了应答，当超过半数应答时，leader 就可以确认自己还是当前集群的 leader。

```
type readOnly struct {
	option ReadOnlyOption
	pendingReadIndex map[string]*readIndexStatus
	readIndexQueue []string
}
```
readOnly 用于管理全局的 readIndx 数据，其中：

- option：readOnly 选项。
- pendingReadIndex：当前所有待处理的 readIndex 请求，其中 key 为客户端读请求的唯一标识。
- readIndexQueue：保存所有 readIndex 请求的请求唯一标识数组。

有了以上的数据结构介绍，后面是流程介绍：

server 收到客户端的读请求，此时会调用 raft.ReadIndex 函数发起一个 MsgReadIndex 的请求，带上的参数是客户端读请求的唯一标识（此时可以对照前面分析的 MsgReadIndex 及其对应应答消息的格式）。

follower 将向 leader 直接转发 MsgReadIndex 消息，而 leader 收到不论是本节点还是由其他 server 发来的 MsgReadIndex 消息，其处理都是：

- a. 首先如果该 leader 在成为新的 leader 之后没有提交过任何值，那么会直接返回不做处理。
- b. 调用 r.readOnly.addRequest(r.raftLog.committed, m) 保存该 MsgreadIndex 请求到来时的 commit 索引。
- c .r.bcastHeartbeatWithCtx(m.Entries[0].Data)，向集群中所有其他节点广播一个心跳消息 MsgHeartbeat，并且在其中带上该读请求的唯一标识。
- d. follower 在收到 leader 发送过来的 MsgHeartbeat，将应答 MsgHeartbeatResp 消息，并且如果 MsgHeartbea t 消息中有 ctx 数据，MsgHeartbeatResp 消息将原样返回这个 ctx 数据。
- e. leader 在接收到 MsgHeartbeatResp 消息后，如果其中有 ctx 字段，说明该 MsgHeartbeatResp 消息对应的 MsgHeartbeat 消息，是收到 ReadIndex 时 leader 消息为了确认自己还是集群 leader 发送的心跳消息。首先会调用 r.readOnly.recvAck(m) 函数，根据消息中的 ctx 字段，到全局的 pendingReadIndex 中查找是否有保存该 ctx 的带处理的 readIndex 请求，如果有就在 acks map 中记录下该 follower 已经进行了应答。
- f. 当 ack 数量超过了集群半数时，意味着该 leader 仍然还是集群的 leader，此时调用 r.readOnly.advance(m) 函数，将该 readIndex 之前的所有 readIndex 请求都认为是已经成功进行确认的了，所有成功确认的 readIndex 请求，将会加入到 readStates 数组中，同时 leader 也会向 follower 发送 MsgReadIndexResp。
- g. follower 收到 MsgReadIndexResp 消息时，同样也会更新自己的 readStates 数组信息。
- h. readStates 数组的信息，将做为 ready 结构体的信息更新给上层的 raft 协议库的使用者。
需要特别说明的是，处理读请求时，实际上 leader 需要确保当前自己是不是 leader、该读请求对应的 commit 索引是否得到了半数投票，而当一个节点刚成为 leader 的时候，如果没有提交过任何数据，那么在它所在的这个任期（term）内的 commit 索引当时是并不知道的，因此在成为 leader 之后，需要马上提交一个 no-op 的空日志，这样拿到该任期的第一个 commit 索引。

![在这里插入图片描述](https://images.gitbook.cn/8dfcbb30-24f5-11eb-92b5-afb3bf7a9e76)

上图中，在 leader 收到 MsgReadIndex 后：

向 readOnly 中添加与这次请求 ctx 相关的数据：

向 pendingReadIndex 中添加以 ctx 为 key 的 readIndexStatus，其中保存了当前的 commitIndex、原始的 MsgReadIndex 消息、以及用于存放有哪些节点应答了该消息的 acks 数组。向 readIndexQueue 数组中添加 ctx。leader 向集群中其他节点广播 MsgHeartbeat 消息，其中带上这次 MsgReadIndex 的 ctx。在这之后，follower 应答 leader 的 MsgHeartbeat 消息，如果消息中存在 ctx 字段都会带上应答，于是 leader 中的处理：

收到 MsgHeartbeatResp 消息之后，如果发现其中有 ctx，就去计算应答有没有超过半数，没有超过半数则返回。

走到这里就是超过半数应答了，此时拿到新的 readIndexStatus 数组。

遍历前面拿到的 readIndexStatus 数组，生成新的 readStates 数组。
放到 Ready 中下一次给客户端。

总结一下，分为四步：

1. leader 检查自己在当前任期有没有 commit 过一条 entry，没有提交过则不允许处理 readIndex 请求。
2. leader 记录下来收到 readIndex 请求时候的 commit index ，然后 leader 向集群中所有节点发心跳广播，其中带上 readIndex 相关的 ctx 字段。
3. 当超过半数的节点应答了第二部的心跳消息，说明此时 leader 还是集群的 leader。
4. 生成新的 readStates 数组放入 Ready 结构体中，等待下一次客户端来获取该数据。

### 基于 Etcd-Raft 实现简单分布式 KV 存储实验

我们使用 raftexample 来实现 Etcd-Raft 库的使用，上述文章中提到过，这个项目在 etcd 项目里面的 contrib 目录下，体演示了如何使用 etcd-raft 库实现一个对外提供 REST API 的简单 key-value 存储集群。

#### 构建 raftexample 项目

首先我们来 build raftexample 项目

下载 etcd git 代码仓库到 `<directory>/src/go.etcd.io/etcd` 

运行命令

```sh
export GOPATH=<directory>
cd <directory>/src/go.etcd.io/etcd/contrib/raftexample
go build -o raftexample
```
#### 运行单节点的 raftexample
首先我们来启动一个单节点集群：

```sh
raftexample --id 1 --cluster http://127.0.0.1:12379 --port 12380
```
每个 raftexample 进程运行着一个 raft 实例和一个 key-value 服务。 --cluster 可以指定集群中的成员（用逗号分割地址），--id 指定 raft 实例 id，--port 指定 http key-value 服务器的监听地址。

接下来，我们往服务器中写一个 value 为 ("hello" ) 的 key ("mykey")

```
curl -L http://127.0.0.1:12380/my-key -XPUT -d hello
```
最后我们来验证下这个 key 的读取
```
curl -L http://127.0.0.1:12380/my-key
```

#### 运行一个本地集群

首先我们安装 https://github.com/mattn/goreman，它可以用来管理使用 Procfile 文件里面指定的运行应用。

这个实验 Procfile 的内容如下：
```
# Use goreman to run `go get github.com/mattn/goreman`
raftexample1: ./raftexample --id 1 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 12380
raftexample2: ./raftexample --id 2 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 22380
raftexample3: ./raftexample --id 3 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 32380
```
然后我们来启动集群：
```
goreman start
```
这个命令会启动一个三实例的 raft k-v 服务集群。接下来我们可以对这个集群做容灾测试了。

首先我们往集群中一个节点写入值 ("foo")
```
curl -L http://127.0.0.1:12380/my-key -XPUT -d foo
```
接下来，移除集群中的一个节点，然后继续往集群中写入 "bar" 来验证集群的可用性：

```
goreman run stop raftexample2
curl -L http://127.0.0.1:12380/my-key -XPUT -d bar
curl -L http://127.0.0.1:32380/my-key
```
最后我们恢复停止的节点，来验证下恢复过程是否生效，我们在 raftexample2 读取 value ("bar")
```
goreman run start raftexample2
curl -L http://127.0.0.1:22380/my-key
```

#### 动态的配置集群中的节点
我们可以使用服务器提供的 REST API 动态的往集群中增加和删除节点。

我们来实验一下，首先启动一个 3 节点集群：
```
raftexample --id 1 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 12380
raftexample --id 2 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 22380
raftexample --id 3 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 32380
```
添加一个 ID 为 4 的节点到集群中：

```
curl -L http://127.0.0.1:12380/4 -XPOST -d http://127.0.0.1:42379
```
使用 `--join` 选项加入原来的 3 节点集群：
```
raftexample --id 4 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379,http://127.0.0.1:42379 --port 42380 --join
```
新的节点就被加到原先的集群，并且开始服务 key/value 请求
我们可以使用 DELETE 请求来移除集群中的节点

```
curl -L http://127.0.0.1:12380/3 -XDELETE
```
发送这个命令后，节点 3 会停止服务。

### 参考

-  *In Search of an Understandable Consensus Algorithm
(Extended Version)*
-  codedump 网络日志 - etcd-raft 库分析

