[TOC]

### 本文知识结构

![在这里插入图片描述](https://images.gitbook.cn/b405fc40-d335-11ea-85df-d329dec560b9)

### 存储引擎在数据库系统架构中的定位

数据库管系统通常使用的是数据库管理系统使用的是 [客户机/服务器] 模型，其中数据库节点扮演服务器的角色，用户应用程序扮演客户机的角色，下图展示了一个常见的数据库管理系统的架构。

![在这里插入图片描述](https://images.gitbook.cn/f3d2d510-cb0f-11ea-b688-650c3ca7b2d2)

客户端请求通过传输层 [Transport] 到达子系统，请求是以查询的形式出现，通常是某种查询语言 [如 SQL]。传输层 [Transport] 还负责了数据库集群中节点之间的通信。

系统在接收到查询后，查询处理器负责对其进行解析、解释和验证。然后进行执行访问控制检查，因为只有在解析查询后才能完全执行这些检查。

​解析后的查询被传递给查询优化器，优化器消除查询中不可能的条件如 [where 1 = 2] 和冗余的部分，然后根据内部统计信息和数据防止的节点位置，进行查询优化。

​查询通常以执行计划的形式表示，效率不同的执行计划可以满足相同的查询，所以查询优化器会选择最佳的执行计划。

执行计划最终交给执行引擎处理，执行引擎会收集本地和远程的执行结果。通常远程执行可能涉及到向集群中的其他节点写入和读取数据，以及复制数据。

本地的查询由**存储引擎**执行，存储引擎有几个核心的组件：

- 事务管理器：调度执行数据库事务，确保数据库不会出现逻辑不一致的状态。
- 锁管理器：这个管理器为正在运行的事务锁定数据库对象，以确保并发操作不会破坏数据完整性。
- 访问方法：它们管理磁盘上的访问以及组织数据。访问方法包括堆文件和存储结构，例如 B 树或者 LSM 树。
- 缓冲区管理器：它将数据页缓存在内存中。
- 恢复 [recovery] 管理器：它维护了用户操作的日志，并在出现故障时恢复系统状态。

事务和锁管理器一起负责并发控制：它们保证逻辑和物理数据的完整性，同时确保尽可能高效的执行并发操作。

### Go LevelDB 源码编译

**1\. 下载源码**

从 GitHub 下载源码，注意要放到你环境的 GOPATH 对应目录下

```
git clone https://github.com/syndtr/goleveldb.git
```
![在这里插入图片描述](https://images.gitbook.cn/2be00b80-cb10-11ea-b02c-bdb8cb34a02c)

**2\. 下载依赖**

我们可以看到源码是用 go mod 管理的，如果你低版本的 Go 环境，请升级 Go 到 1.11 及以上版本

![在这里插入图片描述](https://images.gitbook.cn/368df650-cb10-11ea-b02c-bdb8cb34a02c)

go.sum 文件里面定义了 goleveldb 项目的所有以来库，包括了仓库信息以及版本信息

我们可以在项目根目录下执行

```
export GO111MODULE=on
go mod download
go mod vendor
```

下载并缓存依赖到项目根目录下的 vendor 文件夹中。

**3\. 运行测试**

goleveldb 已经内置和很多测试，你可以通过以下命令运行测试，运行测试前 Go 运行环境会编译你的测试代码。

```
go test github.com/syndtr/goleveldb/leveldb -v
```
![在这里插入图片描述](https://images.gitbook.cn/586b6550-cb10-11ea-8e40-295b7e83c755)

![在这里插入图片描述](https://images.gitbook.cn/605cc830-cb10-11ea-ade4-5553ba678214)

可以看到 65 个测试完全通过，优秀的工程代码总是包含的详尽的测试信息，这个习惯值得大家在项目开发时借鉴。

### Go LevelDB 使用示例

**1\. 使用示例**

我们可以在项目根目录创建一个测试文件，内容如下

![在这里插入图片描述](https://images.gitbook.cn/6ad63580-cb10-11ea-b841-61df797ce75a)

建议大家敲一遍，熟悉使用，代码内容如下：

```
package goleveldb

import (
	"github.com/syndtr/goleveldb/leveldb"
	"testing"
)

func TestDemo1(t *testing.T)  {
	db, err := leveldb.OpenFile("/tmp/test", nil)
	if err != nil {
		t.Log(err.Error())
		return
	}
	if db != nil {
		t.Log("put key:")
		if err := db.Put([]byte("key"), []byte("gitchat test"), nil); err != nil {
			t.Log(err.Error())
		}
	}
	if data, err := db.Get([]byte("key"), nil); err == nil {
		t.Log("get key result:")
		t.Log(string(data))
	} else {
		t.Log(err.Error())
		return
	}
	if err := db.Delete([]byte("key"), nil); err != nil {
		t.Log(err.Error())
		return
	}
	// read a deleted key
	if data, err := db.Get([]byte("key"), nil); err == nil {
		t.Log("get key result:")
		t.Log(string(data))
	} else {
		t.Log(err.Error())
		return
	}
	defer db.Close()
}
```

要运行这段代码你可以在项目根目录使用以下命令：

```
go test -v demo_test.go
```

这个实例中，我们向引擎中写入一个 key，然后读取它，最后删除这个 key，再次读取它，我们将得到如下输出结果。

![在这里插入图片描述](https://images.gitbook.cn/787c51b0-cb10-11ea-b02c-bdb8cb34a02c)

### LevelDB 整体架构

leveldb 中主要由以下几个重要的部件构成

- memtable
- immutable memtable
- log (journal)
- sstable
- manifest
- current

整体架构图如下：

![在这里插入图片描述](https://images.gitbook.cn/8dbe1d20-cbb4-11ea-a9c6-6d383b8a0f1f)

接下来，我们来依次给出每个模块的介绍

#### memtable

leveldb 的一次写入操作并不是直接的将数据落盘，而是首先写入到一个内存中的数据结构-Memtable。在 memtable 中，所有的数据按用户定义的排序方法排序之后按顺序存储，等到其存储内容达到阈值时（默认为 4MB），便将其转换成一个不可修改的 memtable，与此同时创建一个新的 memtable，供用户继续的进行读写操作。memtable 底层使用了一种叫做跳表(skiplist)的数据结构，这个数据结构设计的初衷就是取代平衡树的，它绝大多数操作的时间复杂度为 O(log n)。

#### immutable memtable

memtable 的容量到达阈值时，便会转换成一个不可以修改的 memtable，也称为 immutable memtable。这两者的结构定义是完全一样的，区别只是 immutable memtable 是只读的。当一个 immutable memtable 被创建时，leveldb 的后台压缩进程便会将利用其中存储的内容，创建生成一个 sstable，并持久化到磁盘文件中。

#### log

leveldb 的写操作并不是直接写入磁盘的，而是首先写入到内存。假设写入到内存的数据还未来得及持久化，leveldb 进程发生了异常，或者是宿主机此时发生了宕机，会造成用户写入数据发生丢失。因此 leveldb 在写内存之前会首先将所有的写操作写到日志文件中，也就是 log 文件。当下列常见异常情况发生的时候，可以通过日志文件来恢复数据内容：

- 写 log 期间进程异常
- 写 log 完成，写内存未完成
- write 动作完成 (即 log、内存都写入完成) 后，进程异常
- Immutable memtable 持久化过程中进程异常
- 其他的异常，如压缩异常

当第一种情况发生时，数据库重启读取 log 时，发现异常日志数据，就抛弃该日志数据，即视作这次用户写入失败，保障了数据库的一致性。

当第二、三、四中情况发生了，均可以通过 redo 日志文件中记录的写入操作完成数据库的恢复，每次针对日志文件的写都是一次顺序写，因此写效率很高，整体的写入性能较好。此外，leveldb 的用户写操作的原子性也是通过日志来保证的(我们后面会详细讲到)。

#### sstable

虽然 leveldb 采用了先写内存的方式来提高写入效率，但是内存中数据不可能无限增长，并且日志记录的写入操作过多，会导致异常的发生，恢复时间过程。因此内存中的数据达到一定容量，就需要将数据持久化到磁盘中。除了某些元数据文件，leveldb 的数据主要都是通过 sstable 来进行存储。

虽然在内存中，所有的数据都是按序排序的，但是当多个 memtable 数据持化到磁盘后，对应不同的 sstable 之间是存在交集的，在读操作时，需要对所有的 sstable 文件进行遍历，严重影响了读取效率。因此 leveldb 后台会“定期”整合这些 sstable 文件，该过程也称为 compaction。随着 compaction 的进行，sstable 文件在逻辑上被分成若干层，有内存数据直接 dump 出来的文件称为 level 0 层文件，后期整合而成的文件为 level i 层文件，这就是 leveldb 这个名字的由来。

#### manifest

leveldb 中有个版本的概念，一个版本中主要记录了每一层中所有文件的元数据，元数据包括

- 文件大小
- 最大 key 值
- 最小 key 值

这个版本信息十分关键，除了在查找数据时，利用维护的每个文件的最大/最小 key 值来加速查找，还在其中维护了一些进行 compaction 的统计值，来控制 compaction 的进行。

以上午 go 实现 leveldb 为例，一个文件的元数据主要包括了最大最小 key，文件大小信息等：

```
// tFile holds basic information about a table.
type tFile struct {
	fd storage.FileDesc
	seekLeft int32
	size int64
	imin, imax internalKey
}
```

一个版本信息主要维护了每一层所有文件的元数据。

```
type version struct {
	s *session // session - version
	levels []tFiles // file meta
	// Level that should be compacted next and its compaction score.
	// Score < 1 means compaction is not strictly needed. These fields
	// are initialized by computeCompaction()
	cLevel int // next level
	cScore float64 // current score
	cSeek unsafe.Pointer
	closing bool
	ref int
	released bool
}
```
当每次 compaction 完成 (也就是每次 sstable 文件增加或者减少)， leveldb 都会创建一个新的 version，创建的规则是:

```
versionNew = versionOld + versionEdit
```
versionEdit 指代的是基于旧版本基础上，变化的内容（例如新增或删除了某些 sstable 文件）。

manifest 文件就是用来记录这些 versionEdit 信息的。一个 versionEdit 数据，会被编码成一条记录，写入 manifest 文件中。例如下图便是一个 manifest 文件的示意图，其中包含了 3 条 versionEdit 记录，每条记录包括

- 新增了哪些 sst 文件
- 删除哪些 sst 文件
- 当前 compaction 的下标
- 日志文件编号
- 操作 seqNumber 

通过这些信息，leveldb 便可以在启动时，基于一个空的 version，不断 apply 这些记录，最终将得到一个上次运行结束时的版本信息。

![在这里插入图片描述](https://images.gitbook.cn/2682e1f0-ccda-11ea-9ffc-ad9c6909d216)

#### current

这个文件的内容只有一个信息，就是记载当前 manifest 文件名。
因为每次 leveldb 启动时，都会创建一个新的 manifest 文件。因此数据目录可能会存在多个 Manifest 文件。Current 则用来指出哪个 Manifest 文件才是我们关心的那个 Manifest 文件。

### 读写操作

#### 写操作

leveldb 以优秀的写性能出名，我们先来分析一下 leveldb 整个写入的流程，底层的数据结构支持，以及为什么能获得那么高的写入性能。

##### 整体流程

leveldb 的一次写入通常分成两步：

1. 将写操作写入日志；
2. 将写操作应用到内存数据库中。

![在这里插入图片描述](https://images.gitbook.cn/4ea9ad60-ce80-11ea-bf20-49fb83ee77e0)

##### 写类型

levedb 对外暴露的写入接口有：	(1) Put (2) Delete 两种。这两种操作其实本质上对应同一种操作，Delete 操作同样会被转换成一个 value 为空的 Put 的操作。

除此之外，leveldb 还提供了一个批处理的工具 Batch ，用户可以使用 Batch 来完成批量的数据库更新操作，并且保证这些操作都是原子性的。

##### batch 结构

无论是 Put/Del 操作，还是批量的操作，leveldb 底层都会为这些操作创建一个 batch 实例作为一个数据库操作的最小执行单元。我们首先来介绍一下 batch 的组织结构。

![在这里插入图片描述](https://images.gitbook.cn/6a18e1a0-ce81-11ea-af9a-b958e5b9ed23)

在 batch 中，每一条数据项都按照上图的格式进行编码。每条数据项编码后的第一位是这条数据项的类型（更新还是删除），之后是数据项 key 的长度，数据项 key 的内容：如果改数据项不是删除操作，则再加上 value 的长度，value 的内容。

batch 中会维护一个 size 只，用于表示其中包含的数据量的大小。该 size 的值作为所有数据项 key 与 value 长度的累加，以及每条数据项额外的 8 个字节。这 8 个字节用于存储一条数据项额外的一些信息。

##### key 值编码

当数据项从 batch 中写入到内存数据库中时，需要将一个 key 值进行转换，在 leveldb 内部，所有数据项的 key 是经过特殊编码的，这种格式称为 internalKey。

internalKey 在用户 key 的基础上，尾部追加了 8 个字节，用于存储

- 该操作对应的 sequence number
- 该操作的类型

![在这里插入图片描述](https://images.gitbook.cn/7c785870-ce87-11ea-844f-25301d5fb3e2)

其中，每一个操作都会被赋予一个 sequence number。该计数器是在 leveldb 内部维护的，每进行一次操作就做一次累加。由于在 leveldb 中，一次更新或者一次删除，采用的都是 append 的方式，而并非直接更新原数据。因此对应同样一个 key，会有多个版本的数据记录，而最大的 sequence number 对应的数据记录就是最新的。

此外，leveldb 的快照 (snapshot) 也是基于这个 sequence number 实现的，即每一个 sequence number 代表着数据库的一个版本。

##### 合并写

leveldb 中，在面对并发写入时，做了一个处理的优化。在同一个时刻，只允许一个写入操作将内容写入到日志文件以及内存数据库中。为了在写入进程较多的情况下，减少日志文件的小写入，增加整体的写入性能，leveldb 将一些 “小写入” 合并成一个 “大写入”。

流程如下图所示：

![在这里插入图片描述](https://images.gitbook.cn/c6076930-ce88-11ea-bf22-53df9991351f)

**第一个获取到写锁的写操作**

- 第一个写入操作获取到写入锁；
- 在当前写操作的数据量还没达到合并的上限，并且有其他写操作 pending 的情况下，将其他写操作的内容合并到自身；
- 若本次写操作的数据量超过上限，或者无其他 pending 的写操作了，就将所有内容统一写到日志文件，并写入到内存数据库中；
- 通知每一个被合并的写操作最终的写入结果，释放或移交写锁。

**其他写操作**

- 等待获取写锁喝着被合并；
- 若被合并，判断是否合并成功，若成功，则等待最终写入结果；反之，则表明获取锁的写操作已经 oversize 了，这个时候，该操作直接从上个占有锁的写操作中结果写锁进行写入；
- 若未被合并，则继续等待写锁或等待被合并。

##### 原子性

leveldb 的任意一个写操作，其原子性都是由日志文件实现的。一个写操作中所有的内容都会以一个日志中的一条记录，作为最小单位写入。

考虑以下两种异常情况：

- 写日志未开始，或写日志完成一半，进程异常退出；
- 写日志完成，进程异常退出。

前者中可能存储一个写操作的部分已经被记录到日志文件中，仍然有部分写未被记录，在这种情况下，当数据库重新启动恢复时，读到这条日志记录时，发现数据异常，直接丢弃或退出，实现了写入的原子性保障。

后者，写日志已经完成，但是数据并未真正的持久化，数据库启动恢复时通过 redo 日志实现数据写入，仍然保障了原子性。

#### 读操作

leveldb 提供给用户两种进行读取数据的接口：

- 直接通过 Get 接口读取数据；
- 首先创建一个 snapshot，基于 snapshot 调用 Get 接口读取数据。

两者的本质是一样的，只不过第一种调用方式默认地以当前数据库的状态创建了一个 snapshot，并基于此 snapshot 进行读取。

在介绍读操作之前，我们首先来介绍一下快照。

##### 快照

快照代表这数据库某一个时刻的状态，在 leveldb 中，作者巧妙地用一个整型数来代表一个数据库状态。

在 leveldb 中，用户对同一个 key 的若干次修改是一维护多条数据项的方式进行存储的（直到进行 compaction）时才会合并成同一条记录，每条数据想都会被赋予一个序列号，代表这条数据项的新旧状态。一条数据项的序列号越大，表示其中代表其中内容为最新值。

因此，每一个序列号，其实就代表 leveldb 的一个状态。换句话说，每一个序列号都可以作为一个状态快照。

当用户主动或者被动的创建一个快照时，leveldb 会以当前最新的序列号对其赋值。例如图中用户在序列号为 98 的时刻创建了一个快照，并且基于该快照读取 key 为 "name" 的数据时，即便此刻用户将 "name" 的值修改为 "dog" ，再删除，用户读取到的内容仍然是 "cat"。

![在这里插入图片描述](https://images.gitbook.cn/ac0249a0-cef2-11ea-97bd-0b9883095044)

在获取到一个快照后，leveldb 会为本次查询的 key 构建一个 internalKey，其中 internalKey 的 seq 字段使用的便是快照对应的 seq。通过这种方式可以过滤掉所有 seq 号大于快照号的数据项。

#### 读取

![在这里插入图片描述](https://images.gitbook.cn/814bd210-cf4e-11ea-a596-ff71cf4ae2b1)

leveldb 读取分为三步：

1. 在 memory db 中查找指定的 key，若搜索到符合条件的数据项，结束查找；
2. 在冻结的 memory db 中查找指定的 key，若搜索到符合条件的数据项，结束查找；
3. 按低层至高层的顺序在 level i 层的 sstable 文件中查找指定的 key，若搜索到符合条件的数据项，结束查找，否则返回 Not Found 错误，表示数据库中不存在指定的数据。

在 memory db 或者 sstable 的查找过程中，需要根据指定的序列号拼接成一个 internalKey，查找用户 key 一致，且 seq 号不大于指定 seq 号的数据。
 
### 日志

为了防止写入内存的数据库因为进程异常、系统掉电等情况发生丢失，leveldb 在写内存之前会将本次写操作的内容写入日志文件中。

![在这里插入图片描述](https://images.gitbook.cn/0e754b10-cf51-11ea-b298-a5980080dc1d)

在 leveldb 中，有两个 memory db, 以及对应的两份日志文件。其中一个 memory db 是可读写的，当这个 db 的数据量超过预定的上限时，便会转换成一个不可读的 memory db，与此同时，与之对应的日志文件也会变成一份 frozen log。

而新生成的 immutable memory db 则会由后台的 minor compaction 进程将其转换成一个 sstable 文件进行持久化存储，这个过程完成之后，与之对应的 frozen log 将被删除。

#### 日志结构

![在这里插入图片描述](https://images.gitbook.cn/88b3e3e0-cf52-11ea-a596-ff71cf4ae2b1)

为了增加读取效率，日志文件中按照 block 进行划分，每个 block 的大小为 32KiB。每个 block 中包含了若干个完整的 chunk。

一条日志记录包含一个或多个 chunk。每个 chunk 包含一个 7 字节大小的 header，前 4 字节是该 chunk 的校验码，紧接的 2 字节是 chunk 数据的长度，以及最后一个字节是该 chunk 的类型。其中 checksum 校验的范围包括 chunk 的类型以及随后的 data 数据。

chunk 共有四种类型：full, first, middle, last。一条日志记录若只包含一个 chunk，则该 chunk 的类型为 full。若一条日志记录包含多个 chunk，则这些 chunk 的第一个类型为 first，最后一个类型为 last，中间包含大于等于 0 个 middle 类型的 chunk。

由于一个 block 的大小为 32KiB，因此当一条日志文件过大时，会将一部分数据写在第一个 block 中，且类型为 first，若剩余的数据仍然超过一个 block 的大小，则第二部分数据写在第二个 block 中，类型为 middle，最后剩余的数据写在最后一个 block 中，类型为 last。

#### 日志内容

日志的内容为写入的 batch 编码后的信息。

具体的格式为：

![在这里插入图片描述](https://images.gitbook.cn/5f46c850-cfc6-11ea-8ccb-531cc4208b01)

一条日志记录的内容包含：

- Header
- Data

其中 header 中有

- 当前 db 的 sequence number
- 本次日志记录中所包含的 put/del 操作的个数

batch 的编码可以看到读写操作那一小节。

#### 日志写

![在这里插入图片描述](https://images.gitbook.cn/efdc5510-cfc6-11ea-b034-6db4dc671226)

日志写入流程较为简单，在 leveldb 内部，实现了一个 journal（leveldb 的日志实现模块） writer。首先调用 Next 函数获取一个 singleWriter，这个 singleWriter 的作用就是写入一条 journal 记录。

singleWriter 开始写入时，标志这第一个 chunk 开始写入。在写入的过程中，不断判断 writer 中 buffer 的大小，若超过 32KiB，将 chunk 开始到现在作为一个完整的 chunk，为其计算 header 之后将整个 block 写入文件中。同时，重置 buffer 内容，开始新的 chunk 的写入。

若一条 journal 记录较大，则可能会分成几个 chunk 存储在若干个 block 中。

#### 日志读

![在这里插入图片描述](https://images.gitbook.cn/b9d5a790-cfc7-11ea-b588-dbd927221de1)

日志读取也较为简单，为了避免频繁的 IO 读取操作，每次从文件中读取数据时，按 block （32KiB）进行块读取。

每次读取一条日志记录，reader 调用 Next 函数返回一个 singleReader。singleReader 每次调用 Read 函数就返回一个 chunk 的数据。每次读取一个 chunk，都会检查这批数据的校验码、数据类型、数据长度等信息是否正确，若不正确，且用户要求严格的正确性，则返回错误，否则就丢弃整个 chunk 的数据。

循环调用 singleReader 的 read 函数，直至读取到一个类型为 Last 的 chunk，表示整条日志记录都读取完毕，返回。

### 内存数据库

leveldb 中内存数据库用来维护有序 key-value 对，其底层是利用跳表实现，绝大多数操作（读/写）的时间复杂度均为 O(log  n)，有着与平衡树媲美的操作效率，并且实现起来较为简单。

#### 跳表

##### 概述

跳表 (SkipList) 是由 William Pugh 提出的。他在论文呢 《Skip lists: a probabilistic alternative to balanced trees》中详细的介绍了跳表的结构、插入和删除操作的细节。

这个数据结构的核心思想是利用**概率均衡**的技术，加快简化插入、删除操作，且保证绝大多数操作均拥有 O(log n)的良好效率。

下面是论文中介绍跳表的摘录：

```
Skip lists are a data structure that can be used in place of balanced trees.
Skip lists use probabilistic balancing rather than strictly enforced balancing
and as a result the algorithms for insertion and deletion in skip lists are
much simpler and significantly faster than equivalent algorithms for
balanced trees.
```
平衡树（以红黑树为代表）是一种非常复杂的数据结构，为了维持树结构的平衡，获取稳定的查询效率，平衡树每次插入可能会涉及到较为复杂的节点旋转等操作。作者设计跳表的目的就是借助**概率平衡**，来构建一个快速且简单的数据结构，用来取代平衡树。

作者从链表讲起，一步步引出了跳表这种结构的由来：

![在这里插入图片描述](https://images.gitbook.cn/fad7acb0-cfff-11ea-ac11-e713d24749d6)

- 图 a 中，所有元素按顺序排列，被存储在一个链表中，则一次查询最多比较 N 个链表节点；
- 图 b 中，每隔 2 个链表节点，新增一个额外的指针，该指针指向间距为 2 的下一个节点，如此以来，借助这些额外的指针，一次查询至多只需要 n/2 + 1 次比较；
图 c 中，在图 b 的基础上，每隔 4 个链表节点，新增一个额外的指针，指向间距为 4 的下一个节点，一次查询至多需要 n/4 + 2 次比较。

作者推论，若每隔 2^i 个节点，新增一个辅助指针，最终一次节点的查询效率为 O(log n)。但是这样不断地新增指针，使得每一次插入、删除操作将会变得非常复杂。

一个拥有 k 个指针的节点称为一个 k 层节点。按照上面的逻辑，50%的节点为 1 层节点，25% 的节点为 2 层节点，12.5%的节点为 3 层节点。若保证每层节点的分布如上述概率所示，则仍然能够有相同的查询效率，图 e 就是一个示例。

维护这些辅助指针将会带来较大的复杂度，因此作者将每一层中，每个节点的辅助指针指向该层中下一个节点。故在插入删除操作时，只需要跟操作链表一样，修改相关的前后两个节点的内容即可完成，作者将这种数据结构称为跳表。

##### 结构

![在这里插入图片描述](https://images.gitbook.cn/bd1f5c10-d00e-11ea-ac81-2b0026b8359b)

一个跳表的结构示意图如上所示。

跳跃表是按层建造的，底层是一个普通的有序链表。每个更高层都充当下面链表的 “快速通道”。

##### 查找

![在这里插入图片描述](https://images.gitbook.cn/5cf9f280-d010-11ea-9783-dd8480e0636f)

在介绍插入和删除操作之前，我们首先介绍查找操作，该操作是上述两个操作的基础。

例如图中，需要查找一个值为 17 的元素，查找的过程为：

- 首先根据跳表的高度选取最高层的头节点；
- 若跳表中的节点内容小于查找节点的内容，则取该层的下一个节点继续比较；
- 若跳表中的节点内容等于查找节点的内容，则直接返回；
- 若跳表中的节点内容大于查找节点的内容，且层高不为 0 ，则降低层高，且从前一个节点开始，重新查找低一层中的节点信息，若层高为 0，则返回当前节点，该节点的 key 大于所查找节点的 key。

综合来说，就是利用稀疏的高层节点，快速定位到所需要超着节点的大致位置，再利用密集的底层节点，具体比较节点的内容。

##### 插入

插入操作借助于查找操作实现。

- 在查找过程中，不断记录每一层的前任节点；
- 为新插入的节点随机生成高度；
- 在合适的位置插入新的节点，并依据查找时记录的前任节点信息，在每一层中，以链表插入的方式，将该节点插入到每一层的链接中。

链表插入指：将当前节点的 Next 值设置为前任节点的 Next 值，将前任节点的 Next 值替换为当前节点。

![在这里插入图片描述](https://images.gitbook.cn/fa03b5b0-d011-11ea-990a-0b26c05e8912)

##### 删除

跳表的删除操作较为简单，以来查找过程找到该节点在整个跳表中的位置后，以链表删除的方式，在每一层中，删除该节点的信息。

链表删除：将前任节点的 Next 值替换为当前节点的且 Next 值，并将当前节点所占用的资源释放。

##### 迭代

向后遍历

- 若迭代器刚被创建，则根据用户指定的查找范围 [Start, Limit) 找到一个符合条件的跳表节点。
- 若迭代器处于中部，则取出上一次访问的跳表节点的后继节点，作为本次访问的跳表节点。
- 利用跳表节点信息 (key value 数据偏移量，key, value 值长度等)，获取 keyvalue 数据。

向前遍历

- 若迭代器刚被创建，则根据用户指定的查找范围 [Start, Limit) 在跳表中找到最后一个符合条件的跳表节点。
- 若迭代器处于中部，则利用上一次访问节点的 key 值，查找比该 key 值更小的跳表节点。
- 利用跳表节点信息 (key value 数据偏移量，key, value 值长度等)，获取 key value 数据。

#### 内存数据库

在介绍完跳表结构原理后，我们来看一看如何利用跳表来构建一个搞笑的内存数据库。

##### 键值编码

在介绍内存数据库之前，首先介绍一下内存数据库的键值编码规则。由于内存数据库本质就是一个 kv 集合，且所有的数据项都是依据 key 值进行排序的，因此键值的编码规则尤为关键。

内存数据库中，key 称为 internalKey，其由三部分组成；

- 用户定义的 key，这个 key 值也就是原生的 key 值；
- 序列号：leveldb 中，每一次写入操作都有一个 sequence number，标志着写入操作的先后顺序。由于在 leveldb 中，可能会有多条相同 key 的数据项同时存储在数据库中，因此需要有一个序列号来标识这些数据项的新旧情况，序列号最大的数据项为最新值；
- 类型：标志本条数据项的类型，为更新还是删除。

![在这里插入图片描述](https://images.gitbook.cn/0ef32d90-d015-11ea-be40-c3b019fcc8f7)

##### 键值比较

内存数据库中所有的数据项都是按照键值比较规则进行排序的。这个比较规则可以由用户自己定制，也可以使用系统默认的。在这里介绍一下系统默认的比较规则。

默认的比较规则：

- 首先按照字典序比较用户定义的 key（ukey） ，若用户定义 key 值大，整个 internalKey 就大；
- 若用户定义的 key 相同，则序列号大的 internalKey 值就小。

通过这样的比较规则，则所有的数据项首先按照用户 key 进行生序排序；当用户 key 一致时，按照序列号进行降序排序，这样可以保证首先读到序列号大的数据项，也就是最新的数据。

##### 数据组织

我们 golevedb 的代码中，内存数据库的定义如下：

```
type DB struct {
	cmp comparer.BasicComparer
	rnd *rand.Rand
	mu sync.RWMutex
	kvData []byte
	// Node data:
	// [0] : KV offset
	// [1] : Key length
	// [2] : Value length
	// [3] : Height
	// [3..height] : Next nodes
	nodeData []int
	prevNode [tMaxHeight]int
	maxHeight int
	n int
	kvSize int
}
```
其中 kvData 用来存储每一条数据项的 key-value 数据，nodeData 用来存储每个跳表节点的链接信息。

nodeData 中，每个跳表节点占用一段连续的存储空间，每一个字节分别用来存储特定的跳表节点信息。

- 第一个字节用来存储本节点 key value 数据在 kvData 中对应的偏移量；
- 第二个字节用来存储本节点 key 值的长度；
- 第三个字节用来存储本节点 value 值的长度；
- 第四个字节用来存储本节点的层高；
- 第五个字节开始，用来存储每一层对应的下一个节点的索引值。

### sstable

#### 概述

如我们之前提到的，leveldb 是典型的 LSM 树（Log Structured-Merge Tree）实现，即一次 leveldb 的写入过程并不是直接将数据持久化到磁盘文件中，而是将写操作首先写入日志文件中，其次将写操作应用在 memtable 上。

当 leveldb 中 memtable 的数据量超过了预设的阈值，会将当前的 memtable 冻结成一个不可以更改的内存数据库 ( immutable memory db)，并且创建一个新的 memtable 供系统继续使用。

immutable memory db 会在后台进行一次 minor compaction，即将内存数据库中的数据持久化到磁盘文件中。

leveldb 设计 Minor Compaction 的目的是为了：

- 有效降低内存的使用率；
- 避免日志文件过大，系统恢复时间过长。

当 memory db 的数据被持计划到文件中时， leveldb 将以一定规则进行文件组织，这种文件格式成为 sstable。接下来我们将详细的介绍 sstable 的文件格式以及相关的读写操作。

#### SStable 文件格式

##### 物理结构

为了提高整体的读写效率，一个 sstable 文件按照固定大小进行划分，默认每个块的大小为 4KiB。每个 Block 中，除了存储数据意外，还会存储两个额外的辅助字段：

- 压缩类型
- CRC 校验码

压缩类型说明了 Block 中存储的数据是否进行了数据压缩，如果是，采用了哪种算法进行压缩。leveldb 中默认采用 Snappy 算法进行压缩。

CRC 校验码是循环冗余校验校验码，校验数据的范围包括**数据以及其压缩类型**。

![在这里插入图片描述](https://images.gitbook.cn/744e1b70-d06d-11ea-9de2-0b7866720b98)

##### 逻辑结构

在逻辑上，根据功能不同，leveldb 在逻辑上又将 sstable 分为：

- data block: 用来存储 key value 数据对；
- filter block: 用来存储一些过滤器相关的数据，但是用户如果不指定 leveldb 使用过滤器，leveldb 在该 block 中不会存储任何内容；
- meta Index block：用来存储 filter block 的索引信息；
- index block：index block 中用来存储每个 data block 的索引信息；
- footer：用来存储 meta index block 及 index block 的索引信息；
1-4 类型的 block ，物理结构都是上图所示，每个 block 都会有自己的压缩信息以及 CRC 数据校验码信息。

![在这里插入图片描述](https://images.gitbook.cn/4141fdc0-d0c5-11ea-ac4d-ab3375d411dd)

#### data block 结构

data block 中存储的数据是 leveldb 中的 key value 对。其中一个 data block 中的数据部分（不包括压缩类型、CRC 校验码）按逻辑又以下图进行划分：

![在这里插入图片描述](https://images.gitbook.cn/fb46fe50-d0c5-11ea-84e3-8d0d2134fcd2)

第一部分用来存储 key value 数据。由于 sstable 中所有的 key value 对都是严格按照顺序存储的，为了节省存储空间，leveldb 并不会为每一个 key value 对都存储完整的 key 值，而是存储于**上一个 key 非共享的部分**，避免了 key 重复内容的存储。

每间隔若干个 key value 对，将为该条记录重新存储一个完整的 key。重复该过程，每个重新存储完整 key 的点称为 Restart point。

**leveldb 设计 Restart point 的目的是为了读取 sstable 内容时，加速查找的过程。**

由于每个 Restart point 存储的都是完整的 key 值，因此在 sstable 中进行数据查找时，可以首先利用 restart point 点的数据进行 key 值比较，以便于快速定位旧目标数据所在的区域。当确定目标数据所在区域后，再依次对区间内所有数据进行 key 值比较，进行细粒度的查找。

每个数据项的格式如下图所示：

![在这里插入图片描述](https://images.gitbook.cn/bfeb7550-d0c7-11ea-a88c-29cb7b00c966)

一个 entry 分为 5 部分内容：

- 与前一条记录 key 共享部分的长度
- 与前一条记录 key 不共享部分的长度
- value 的长度
- 与前一条记录 key 非共享的内容
- value 的内容

例如：

```
restart_interval=2
entry one : key=deck,value=v1
entry two : key=dock,value=v2
entry three: key=duck,value=v3
```
表示为：

![在这里插入图片描述](https://images.gitbook.cn/3b56c3c0-d0c8-11ea-bd3e-fbc42ddede66)

三组 entry 按上图的格式进行存储。值得注意的是 restart_interval 为 2，因此每隔两个 entry 都会有一条数据作为 restart point 点的数据项，存储完整的 key 值。因此 entry3 存储了完整的 key 值。

此外，第一个 restart point 为 0 ，第二个 restart point 为 16， restart point 共有两个，因此一个 datablock 数据段的末尾添加了下图所示的数据：

![在这里插入图片描述](https://images.gitbook.cn/fc243790-d0c8-11ea-b07e-2bcde3b15887)

尾部记录了每个 restart point 存储偏移量的值，以及所有 restart point 的个数。

#### filter block 结构

为了加快 sstable 中数据查询的效率，在直接查询 datablock 中的内容之前，leveldb 首先根据 filter block 中的过滤数据判断指定的 datablock 中是否有需要查询的数据，若判断不存在，则无需对这个 datablock 进行数据查找。

filter block 存储的是 data block 数据的一些过滤信息。这个过滤数据一般指布隆过滤器（见后面相关章节），用于加快查询的速度。

![在这里插入图片描述](https://images.gitbook.cn/f380f460-d0c9-11ea-aa88-4ba59d0f59ee)

filter block 存储的数据主要可以分为两部分：

- 过滤数据
- 索引数据

其中索引数据中，filter i offset 表示第 i 个 filter data 在整个 filter block 中的起始偏移量，filter offset’s 表示 filter block 的索引数据在 filter block 中的偏移量。

在读取 filter block 中的内容时，可以首先读出 filter offset's offset 的值。然后依次读取 filter i offset，根据这些 offset 分别读出 filter data。

一个 sstable 只有一个 filter block，其内存储了所有 block 的 filter 数据。具体来说，filter_data_k 包含了所有起始位置处于 [base*k, base\*(k+1)] 范围内的 block 的 key 的集合的 filter 数据，按数据大小而非 block 切分主要是为了尽量均匀存储，以应对存在一些 block 的 key 很多，另一些 block 的 key 很少的情况。

#### meta index block 结构

meta index block 用来存储 filter block 在整个 sstable 中的索引信息。

meta index block 只存储一条记录：

- 该记录的 key 为："filter." 与过滤器名字组成的常量字符串
- 该记录的 value 为：filter block 在 sstable 中的索引信息序列化后的内容，索引信息包括：

    - filter block 在 sstable 中的偏移量
    - 数据长度

#### index block 结构

与 meta index block 类似，index block 用来存储所有 data block 的相关索引信息。

![在这里插入图片描述](https://images.gitbook.cn/47686070-d0cc-11ea-aa88-4ba59d0f59ee)

index block 包含若干条记录，每一条记录代表一个 data block 的索引信息。

一条索引信息包括以下内容：

- data block i 中最大的 key 值；
- 该 data block 起始地址在 sstable 中的偏移量；
- 该 data block 的大小。

#### footer 结构

footer 的大小固定，为 48 字节，用来存储 meta index block 与 index block 在 sstable 中的索引信息，另外尾部还会存储一个 magic word，内容为 "http://code.google.com/p/leveldb/" 字符串 sha1 哈希的前 8 个字节。

![在这里插入图片描述](https://images.gitbook.cn/939d0b30-d0cc-11ea-b07e-2bcde3b15887)

#### 读写操作

##### 写操作

sstable 的写操作通常发生在：

- memory db 将内容持久化到磁盘文件中时，会创建一个 sstable 进行写入；
- leveldb 后台进行文件 compaction 时，会将若干个 sstable 文件内容进行重新组织，输出到若干个新的 sstable 文件中。

对 sstable 进行读写操作的数据结构为 tWriter，具体定义如下：

```
// tWriter wraps the table writer. It keep track of file descriptor
// and added key range.
type tWriter struct {
t *tOps
fd storage.FileDesc // 文件描述符
w storage.Writer // 文件系统 writer
tw *table.Writer
first, last []byte
}
```
主要包括了一个 sstable 的文件描述符，底层文件系统的 writer，该 sstable 中所有数据项最大最小的 key 值以及一个内嵌的 tableWriter。

一次 sstable 的写入为一次不断利用迭代器读取需要写入数据的过程，并不断调用 tableWriter 的 Append 函数，直至所有有效数据读取完毕，为该 sstable 文件附上元数据的过程。

- 这个迭代器可以是一个内存数据库的迭代器，写入情况对应上述的 sstable 写操作发生的第一种情况；
- 这个迭代器也可以是一个 sstable 文件的迭代器，写入情景对应上述第二种情况。

所以，理解 tableWriter 的 Append 函数是理解整个写入过程的关键。在介绍 Append 函数之前，首先来看一下 tableWriter 这个数据结构：

```
// Writer is a table writer.
type Writer struct {
	writer io.Writer
	// Options
	blockSize int // 默认是 4KiB
	dataBlock blockWriter // data 块 Writer
	indexBlock blockWriter // indexBlock 块 Writer
	filterBlock filterWriter // filter 块 Writer
	pendingBH blockHandle
	offset uint64
	nEntries int // key-value 键值对个数
}
```
其中 blockWriter 与 filterWriter 表示底层的两种不同的 writer，blockWriter 负责写入 data 数据的写入，而 filterWriter 负责写入过滤说几句。

pendingBH 记录了上一个 dataBlock 的索引信息，当下一个 dataBlock 的数据开始写入时，将该索引信息写入到 indexBlock 中。

**Append 函数**

一次 append 函数的主要逻辑如下：

- 若本次写入新 dataBlock 的第一次写入，则将上一个 dataBlock 的索引信息写入；
- 将 key value 数据写入 datablock；
- 将过滤信息写入 filterBlock；
- 若 datablock 中数据超过预定上限，则标志着本次 datablock 写入结束，将内容刷新到磁盘文件中。

```
// Append appends key/value pair to the table. The keys passed must
// be in increasing order.
//
// It is safe to modify the contents of the arguments after Append returns.
func (w *Writer) Append(key, value []byte) error {
	if w.err != nil {
		return w.err
	}
	if w.nEntries > 0 && w.cmp.Compare(w.dataBlock.prevKey, key) >= 0 {
		w.err = fmt.Errorf("leveldb/table: Writer: keys are not in increasing order: %q, %q", w.dataBlock.prevKey, key)
		return w.err
	}

	w.flushPendingBH(key)
	// Append key/value pair to the data block.
	w.dataBlock.append(key, value)
	// Add key to the filter block.
	w.filterBlock.add(key)

	// Finish the data block if block size target reached.
	if w.dataBlock.bytesLen() >= w.blockSize {
		if err := w.finishBlock(); err != nil {
			w.err = err
			return w.err
		}
	}
	w.nEntries++
	return nil
}
```
**dataBlock.append**

该函数将编码后的 kv 数据写入到 dataBlock 对应的 buffer 中，编码的格式如上文 中提到的数据想的格式。此外，在写入过程中，若该数据项为 restart point，则会添加相应的 restart point 到 datablock 数据段的末尾。

**filterBlock.append**

该函数将 kv 数据项的 key 值加入到过滤器中，我们会在后面 布隆过滤器章节讲到。

**finishBlock**

若一个 datablock 中的数据超过了固定上限，则需要将相关数据写入到磁盘文件中。

在写入时，需要做以下工作：

- 封装 dataBlock，记录 restart point 的个数；
- 若 dataBlock 的数据需要进行压缩，则对 dataBlock 中的数据进行压缩；
- 计算 checksum；
- 封装 dataBlock 索引信息 (offset, length)；
- 将 datablock 的 buffer 中的数据写入磁盘文件；
- 利用这段时间里维护的过滤信息生成过滤器数据，放入 filterBlock 对应的 buffer 中。

**Close 函数**

```
// Close will finalize the table. Calling Append is not possible
// after Close, but calling BlocksLen, EntriesLen and BytesLen
// is still possible.
func (w *Writer) Close() error {
	if w.err != nil {
		return w.err
	}

	// Write the last data block. Or empty data block if there
	// aren't any data blocks at all.
	if w.dataBlock.nEntries > 0 || w.nEntries == 0 {
		if err := w.finishBlock(); err != nil {
			w.err = err
			return w.err
		}
	}
	w.flushPendingBH(nil)

	// Write the filter block.
	var filterBH blockHandle
	w.filterBlock.finish()
	if buf := &w.filterBlock.buf; buf.Len() > 0 {
		filterBH, w.err = w.writeBlock(buf, opt.NoCompression)
		if w.err != nil {
			return w.err
		}
	}

	// Write the metaindex block.
	if filterBH.length > 0 {
		key := []byte("filter." + w.filter.Name())
		n := encodeBlockHandle(w.scratch[:20], filterBH)
		w.dataBlock.append(key, w.scratch[:n])
	}
	w.dataBlock.finish()
	metaindexBH, err := w.writeBlock(&w.dataBlock.buf, w.compression)
	if err != nil {
		w.err = err
		return w.err
	}

	// Write the index block.
	w.indexBlock.finish()
	indexBH, err := w.writeBlock(&w.indexBlock.buf, w.compression)
	if err != nil {
		w.err = err
		return w.err
	}

	// Write the table footer.
	footer := w.scratch[:footerLen]
	for i := range footer {
		footer[i] = 0
	}
	n := encodeBlockHandle(footer, metaindexBH)
	encodeBlockHandle(footer[n:], indexBH)
	copy(footer[footerLen-len(magic):], magic)
	if _, err := w.writer.Write(footer); err != nil {
		w.err = err
		return w.err
	}
	w.offset += footerLen

	w.err = errors.New("leveldb/table: writer is closed")
	return nil
}

```

当迭代器取出所有数据并完成写入之后，调用 tableWriter 的 Close 函数完成最后的收尾工作：

- 若 buffer 中仍有未写入的数据，封装成一个 datablock 写入；
- 将 filterBlock 的内容写入到磁盘文件；
- 将 filterBlock 的索引信息写入到 metaIndexBlock 中，写入到磁盘文件；
- 写入 indexBlock 的数据；
- 写入 footer 的数据。

到此为止，所有的数据就已经被写入到一个 sstable 中了。

##### 读操作

读操作其实就是写操作的逆过程，理解了写操作，将有助于理解读操作。

下图表示在一个 sstable 中该查找某个数据项的流程图：

![在这里插入图片描述](https://images.gitbook.cn/eef74a60-d336-11ea-ad5f-9fce25eeda58)

大致流程为：

- 首先判读 "文件句柄" cache 中是否有指定 sstable 文件的文件句柄，若存在，则直接使用 cache 中的句柄；否则打开该 sstable 文件，按规则读取该文件的元数据，将新打开的句柄存储在 cache 中；
- 利用 sstable 中的 index block 进行快速的数据项位置定位，得到该数据项有可能存在的两个 data block；
- 利用 index block 中的索引信息，首先打开第一个可能的 data block；
- 利用 filter block 中的过滤数据，判断指定的数据项是否存在与该 data block 中，若存在，则创建一个迭代器对 data block 中的数据进行迭代遍历，寻找数据项；若不存在，则结束该 data block 的查找；
- 若在第一个 data block 中找到了目标数据，则返回结果了；若未查找成功，则打开第二个 data block ，重复步骤 4；
- 第二个 data block 中找到了目标数据，则返回结果；若未查找成功，则返回 Not Found 错误信息。

**缓存**

在 leveldb 中，使用 cache 来缓存两类数据：

- sstable 文件句柄及其元数据
- data block 中的数据

在打开文件之前，首先判断能够在 cache 中命中 sstable 的文件句柄，避免重复读取的开销。

**元数据读取**

![在这里插入图片描述](https://images.gitbook.cn/bf6e3a20-d137-11ea-84e3-8d0d2134fcd2)

由于 sstable 复杂的文件组织格式，因此在打开文件后，需要读取必要的元数据，才能访问 sstable 中的数据。

元数据读取的过程可以分为以下几个步骤：

- 读取文件的最后 48 字节，即 Footer 数据；
- 读取 Footer 数据中维护的 (1) Meta Index Block (2) Index Block 两个部分的索引信息并记录，以提高整体的查询效率；
- 利用 meta index block 的索引信息读取该部分的内容；
- 遍历 meta index block，查看是否存在有用的 filter block 的索引信息，若有，则记录该索引信息；若没有，则表示当前 sstable 中不存在任何过滤信息来提高查询效率。

**数据项的快速定位**

sstable 中存在多个 data block，依次进行 “遍历” 显然是不可行的。但是由于一个 sstable 中所有的数据项都是按序排列的，因此可以利用有序性已经在 index block 中维护的索引信息快速定位到目标数据可能在的 data block。

一个 index block 的文件结构示意图如下：

![在这里插入图片描述](https://images.gitbook.cn/d4277610-d156-11ea-a0b7-0bc1e958071c)

index block 是由一系列的键值对组成，每一个键值对表示一个 data block 的索引信息。

键值对的 key 为该 data block 中数据项 key 的最大值，value 为该 data block 的索引信息 (offset, length)。

![在这里插入图片描述](https://images.gitbook.cn/20e27260-d158-11ea-a88c-29cb7b00c966)

因此若需要查找目标数据项，仅仅需要依次比较 index block 中这些索引信息，如果目标数据项的 key 大于某个 data block 的最大 key 值，则该 data block 中最大的 key 值，则该 data block 中必然不存在目标数据项。故通过这个步骤优化，可以直接确定目标数据项落在哪个 data block 的范围区间内。

**过滤 data block**

若 sstable 存有每一个 data block 的过滤数据，则可以利用这些过滤数据对 data block 中的内容进行判断，确定目标数据是否存在于 data block 中。

过滤的原理为：

- 若过滤数据显示目标数据不存在于 data block 中，则目标数据一定不存在于 data block 中；
- 若过滤数据显示目标数据存在于 data block 中，则目标数据可能存在于 data block 中。

具体原理可以参考后续的 布隆过滤器 章节，利用过滤数据可以过滤掉部分 data block，避免发生无所谓的查找。

**查找 data block**

在 data block 中查找目标数据项是一个简单的迭代遍历的过程。虽然 data block 中所有数据项都是暗虚排序的，但是作者并没有采用 "二分查找"  来提高查找效率，而是使用了更大的查找单元进行快速定位。

于 index block 的查找类似，data block 中，以 16 条记录为一个查找单元，若 entry 1 的 key 小于目标数据项的 key，则下一条比较的是 entry 17。

![在这里插入图片描述](https://images.gitbook.cn/bd797690-d159-11ea-b07e-2bcde3b15887)

因此查找的过程中，利用更大的查找单元快速定位目标数据项可能存在哪个区间内，之后依次比较判断其是否存在于 data block 中。可以看到，sstable 很多文件格式设计 （例如 restart point, index block, filter block, max key）在查找的过程中，都极大的提升了整体的查询效率。

#### sstable 文件特点

##### 只读性

sstable 文件为 compaction 的结果原子操作产生的，其余时间都是只读的。

##### 完整性

一个 sstable 文件，其辅助数据：

- 索引数据
- 过滤数据

都存储于同一个文件中。当读取是需要使用这些辅助数据时，无须额外的磁盘读取；当 sstable 文件需要删除时，无须额外的额数据删除操作，也就是说，辅助数据随着文件一起创建和销毁。

##### 并发访问的友好性

由于 sstable 文件具有只读性，因此不存在同一个文件的读写冲突。

leveldb 采用引用计数维护每个文件的引用情况，当一个文件计数值大于 0 时，对次文件的删除操作会等到该文件被释放时才进行，因此实现了无锁情况下的并发访问。

##### Cache 一致性

sstable 文件是只读的，因此 cache 中的数据永远于 sstable 文件中的数据保持一致。

### 缓存系统

缓存对于一个数据库系统读性能影响十分大，如果 leveldb 的每一次读取都会发生一次磁盘 IO，那么其整体效率将会非常低下。

Leveldb 中使用了一种基于 LRUCache 的缓存机制，用于缓存：

- 已打开的 sstable 文件对象和相关元数据
- sstable 中的 dataBlock 的内容

在读取热数据时，尽量在 cache 中命中，避免了每次进行磁盘 IO 读取。

#### Cache 结构

leveldb 中使用的 cache 是一种 LRUCache ，其结构由两部分内容组成：

- Hash table：用来存储数据
- LRU：用来维护数据项的新旧信息

![在这里插入图片描述](https://images.gitbook.cn/2df7a620-d18d-11ea-9407-5d5867460982)

其中 Hash table 是基于 Yujie Liu 等人的论文 《Dynamic-Sized Nonblocking Hash Table》实现的，用来存储数据。由于 hash 表一般需要保证插入、删除、查找等操作的时间复杂度为 O(1)。

当 hash 表的数据量增大时，为了保证这些操作仍然有较为理想的操作效率，需要对 hash 表进行 resize，即改变 hash 表中 bucket 的个数，对所有的数据进行重散列。

基于该文章实现的 hash table 可以实现 resize 的过程中**不阻塞其他并发的读写请求**。

LRU 中则根据 Least Recently Used 原则进行数据新旧信息的维护，当整个 cache 中存储的数据容量达到上限时，便会根据 LRU 算法自动删除最旧的数据，使得整个 cache 的存储容量保持为一个常量。

#### Dynamic-sized NonBlocking Hash table

在 hash 表进行 resize 的过程中，保持无锁并发 （Lock Free）是一件非常困难的事。

一个 hash 表通常由若干个 bucket 组成，每一个 bucket 中会存储若干条被散列至此的数据项。当 hash 表进行 resize 时，需要将“旧”桶中的数据读出，并且重新散列至另外一个“新”的桶中。假设这个过程不是一个原子操作，那么会导致此刻其他的读写操作结果发生异常，甚至可能导致数据丢失。

因此，论文中提出了一个新颖的概念：**一个 bucket 中的数据是可以冻结的**。

这个特点极大的简化了 hash 表在 resize 过程中在不同 bucket 之间转移数据的复杂度。

##### 散列

![在这里插入图片描述](https://images.gitbook.cn/60b2a3b0-d18f-11ea-8f8f-7de25e646dd9)

该哈希表的散列与普通的哈希表一致，都是借助散列函数，将用户需要查找、更改的数据散列到某一个哈希桶中，并在哈希桶中进行操作。

由于一个哈希桶的容量是有限的（一般不大于 32 个数据），因此在哈希桶中进行插入、查找的时间复杂度可以视为常量的。

##### 扩大

当 cache 中维护的数据量太大时，会发生哈希表扩张的情况。以下有两种 cache 中维护数据量过大情况：

![在这里插入图片描述](https://images.gitbook.cn/a2ae9e30-d190-11ea-82c9-11f3d5ebf790)

- 整个 cache 中，数据项 (node) 的个数超过预定的阈值（默认初始状态下哈希桶的个数为 16 个，每个桶中可以存储 32 个数据项）。
- 当 cache 中出现了数据不平衡的情况，当某些桶的数据量超过了 32 个数据，即被视为数据发生了散列不平衡。当这种不平衡累积值超过预定的阈值 （128）个时，就需要进行扩张。

一次扩张的过程为：

- 计算哈希表的哈希桶个数（扩大一倍）；
- 创建一个空的哈希表，并将旧的哈希表转换成一个“过渡期”的哈希表，表中的每个哈希桶都被冻结；
- 后台利用 “过渡期” 哈希表中的 “被冻结” 的哈希桶信息对新的哈希表进行内容构建。

值得注意的是，在完成新的哈希表构建的整个过程中，哈希表并不是拒绝服务的，所有的读写操作仍然可以进行。

哈希表扩张过程中，最小的锁粒度为哈希桶级别。

当有新的读写请求发生时，若被散列之后得到的哈希桶仍然未构建完成，则主动进行构建，并将构建后的哈希桶填入新的哈希表中。后台进程构建到该桶时，发现已经被构建了，则无需重复构建。

因此如上图所示，哈希表扩张结束，哈希桶的个数增加了一倍，于此同时仍然可以对外提供读写服务，仅仅需要哈希桶级别的锁粒度就可以保证所有操作的一致性和原子性。

**构建哈希桶**

当哈希表扩张时，构建一个新的哈希桶其实就是将一个旧的哈希桶中的数据拆分成两个新的哈希桶。

拆分规则很简单。由于一次散列的过程为：

- 利用散列函数对数据项的 key 值进行计算；
- 将第一步得到的结果取哈希桶个数的余，得到哈希桶的 ID。

因此拆分时仅需要将数据 key 的散列值对新的哈希桶个数取余即可。

##### 缩小

当哈希表中数据项的个数少于哈希桶的个数时，需要进行收缩。收缩时，哈希桶的个数变为原先的一半，2 个旧哈希桶的内容被合并成一个新的哈希桶，过程与扩张类似。

#### LRU

除了利用哈希表来存储数据以外，leveldb 还利用 LRU 来管理数据。

Leveldb 中，LRU 利用一个双向循环链表来实现。每个链表项称为 LRUNode。

```
type lruNode struct {
	n *Node // customized node
	h *Handle
	ban bool
	next, prev *lruNode
}
```
一个 LRUNode 除了维护一些链表中前后节点信息以外，还存储了一个哈希表中数据项的指针，通过该指针，当某个节点由于 LRU 策略被驱逐时，从哈希表中安全的删除数据内容。

LRU 主要提供了以下几个接口：

- Promote：若一个 hash 表中的节点是第一次被创建，则为该节点创建一个 LRUNode，并将 LRUNode 至于链表的头部，表示为最新的数据；若一个 hash 表中的节点之前就有相关的 LRUNode 存在与链表中，将该 LRUNode 移至链表的头部；若因为新增加一个	 LRU 数据，导致超出了容量上限，就需要根据策略清除部分节点。
- Ban：将 hash 表节点对应的 LRUNode 从链表中删除，并尝试从哈希表中删除数据。由于该哈希表节点的数据可能正在被其他线程使用，因此需要查看该数据的引用计数，只有当引用计数为 0 时，才可以真正的从哈希表中进行删除。

#### 缓存数据

leveldb 利用上述的 cache 结构来缓存数据。其中：

- cache：来缓存已经被打开的 sstable 文件句柄以及元数据（默认上限为 500 个）；
- bcache：来缓存被读过的 sstable 中 dataBlock 的数据（默认上限为 8MB）。

当一个 sstable 文件需要被打开时，首先从 cache 中寻找是否已经存在相关的文件句柄，若存在则无需重复打开；若不存在，则打开相关文件，并将 indexBlock 数据和 metaIndexBlock 数据等相关元数据进行预读。

### 布隆过滤器

Bloom Filter 是一种空间效率很高的随机数据结构，它利用位十足很简洁地表示一个集合，并能判断一个元素是否属于这个集合。Bloom Filter 的这种高效是有一定代价的：在判断一个元素是否属于某个集合时，有可能会把不属于这个集合的元素误认为属于这个集合。因此，Bloom filter 不适合那些“零错误”的应用场合。而在能容忍低错误率的应用场合下, Bloom Filter 通过极少的错误换取了存储空间的极大节省。

leveldb 中利用布隆过滤器判断指定的 key 值是否存在于 sstable 中，若过滤器表示不存在，则该 key 一定不存在，由此加快了查找的效率。

#### 结构

bloom 过滤器底层是一个位数组，初始时每一位都是 0：

![在这里插入图片描述](https://images.gitbook.cn/c48d2630-d1b2-11ea-bede-db622fe3ca3b)

当插入值 x 后，分别利用 k 个哈希函数（图中为 3 个，3 箭头）利用 x 的值进行散列，并将散列得到的值与 bloom 过滤器的容量进行取余，将取余结果所代表的那一位设置为 1。

![在这里插入图片描述](https://images.gitbook.cn/2fe995d0-d1b3-11ea-9243-7f33b8a1119f)

一次查找过程与一次插入过程类似，同样利用 k 个哈希函数对所需要进行查找的值进行散列，只有散列得到的每个位的值均为 1，才表示该值“有可能”真正存在；反之若有任意一位的值为 0，则表示该值一定不存在。例如下图，y1 一定不存在，y2 可能存在：

![在这里插入图片描述](https://images.gitbook.cn/8f7ce6a0-d1b3-11ea-a457-f1ff303a1ca7)

#### 相关数学结论

与布隆过滤器相关的参数有：

- 哈希函数的个数 k
- 布隆过滤器位数组的容量 m
- 布隆过滤器插入数据的数量 n

数学结论：

1. 为了获得最优的准确率，当 k = ln2 * (m / n) 时，布隆过滤器获得最优的准确性；
2. 在哈希函数的个数取到最优时，要让错误率不超过，m 至少需要取到最小值的 1.44 倍。

#### 实现

leveldb 中布隆过滤器实现较为简单，以 goleveldb 为例，有关代码在 filter/bloom.go 中。

定义如下，bloom 过滤器只是一个 int 数字。

```
type bloomFilter int
```
创建一个布隆过滤器时，只需要指定为每个 key 分配的位数即可，如上小节中结论 2 所示，只要 (m/n) 大于 1.44 即可，一般可以取 10。

```
func NewBloomFilter(bitsPerKey int) Filter {
	return bloomFilter(bitsPerKey)
}
```
创建一个 generator，这一步中需要指定哈希函数的个数 k，可以看到 k = f * ln2，而 f = m/n，数学结论 1.

返回的 generator 中可以添加新的 key 信息，调用 generate 函数时，将所有的 key 构建成一个位数组写在指定的位置。

```
func (f bloomFilter) NewGenerator() FilterGenerator {
	// Round down to reduce probing cost a little bit.
	k := uint8(f * 69 / 100) // 0.69 =~ ln(2)
	if k < 1 {
		k = 1	
	} else if k > 30 {
		k = 30
	}
	return &bloomFilterGenerator{
		n: int(f),
		k: k,
	}
}
```
generator 主要有两个函数：

1. Add
2. Generate

Add 函数中，只是简单地将 key 的哈希散列值存储在一个整型数组中：

```
func (g *bloomFilterGenerator) Add(key []byte) {
	// Use double-hashing to generate a sequence of hash values.
	// See analysis in [Kirsch,Mitzenmacher 2006].
	g.keyHashes = append(g.keyHashes, bloomHash(key))
}
```
Generate 函数中，将之前一段时间内所有添加的 key 信息用来构建一个位数组，该位数组中包含了所有 key 的存在息。

位数组的大小为用户指定的每个 key 所分配的位数乘以 key 的个数。

位数组的最末尾用来存储 k 的大小。

```
func (g *bloomFilterGenerator) Generate(b Buffer) {
	// Compute bloom filter size (in both bits and bytes)
	// len(g.keyHashes) 可以理解为 n， g.n 可以理解为 m/n
	// nBits 可以理解为 m
	nBits := uint32(len(g.keyHashes) * g.n)
	// For small n, we can see a very high false positive rate. Fix it
	// by enforcing a minimum bloom filter length.
	if nBits < 64 {
		nBits = 64
	}
	nBytes := (nBits + 7) / 8
	nBits = nBytes * 8
	dest := b.Alloc(int(nBytes) + 1)
	dest[nBytes] = g.k
	for _, kh := range g.keyHashes {
		// Double Hashing
		delta := (kh >> 17) | (kh << 15) // Rotate right 17 bits
		for j := uint8(0); j < g.k; j++ {
			bitpos := kh % nBits
			dest[bitpos/8] |= (1 << (bitpos % 8))
			kh += delta
		}
	}
	g.keyHashes = g.keyHashes[:0]
}
```
Contain 函数用来判断指定的 key 是否存在。

```
func (f bloomFilter) Contains(filter, key []byte) bool {
	nBytes := len(filter) - 1
	if nBytes < 1 {
		return false
	}
	nBits := uint32(nBytes * 8)

	// Use the encoded k so that we can read filters generated by
	// bloom filters created using different parameters.
	k := filter[nBytes]
	if k > 30 {
		// Reserved for potentially new encodings for short bloom filters.
		// Consider it a match.
		return true
	}

	kh := bloomHash(key)
	delta := (kh >> 17) | (kh << 15) // Rotate right 17 bits
	for j := uint8(0); j < k; j++ {
		bitpos := kh % nBits
		if (uint32(filter[bitpos/8]) & (1 << (bitpos % 8))) == 0 {
			return false
		}
		kh += delta
	}
	return true
}
```
### compaction

Compaction 是 leveldb 最为复杂的过程之一，同样也是 leveldb 性能瓶颈之一。其本质就是一种内部重合数据整合的机制，同样也是一种平衡读写速率的有效手段，因此在下文中，首先介绍下 leveldb 中设计 compaction 的原由，再来介绍下 compaction 的具体过程。

#### Compaction 的作用

##### 数据持久化

leveldb 是典型的 LSM 树实现，因此需要对内存的数据进行持久化。一次内存数据的持久化过程，在 leveldb 中称为 **Minor Compaction**。

一次 minor compaction 的产出是一个 0 层的 sstable 文件，其中包含了所有的内存数据。但是若干个 0 层文件中是可能存在数据 overlap 的。

##### 提高读写效率

leveldb 是一个写效率十分高的存储引擎，存储的过程非常简单，只需要一次顺序文件写和一个时间复杂度为 O(log n) 的内存操作即可。

相比来说，leveldb 的读操作就复杂不少。首先一到两次的读操作需要进行一个复杂度为 O(log n) 的查询操作。若在内存里面没有命中数据，则需要再按照数据的新旧程度在 0 层文件中一次进行查找遍历。由于 0 层文件中可能存在 overlap，因此最差的情况下，可能需要遍历所有的文件。

假设 leveldb 中就是以这样的方式进行数据维护的，那么随着运行时间的增长，0 层的文件个数会越来越多，在最差的情况下，查询一个数据需要**遍历所有的数据文件**，这显然是不可接受的。因此 leveldb 设计了一个 **major compaction** 的过程，将 0 层中的文件合并为若干个没有数据重叠的 1 层文件。

对于没有数据重叠的文件，一次查找过程就可以进行优化，最多只需要一个文件的遍历既完成。因此，leveldb 设计 compaction 的目的之一就是为了 **提高读取的效率。**

##### 平衡读写差异

有了 minor compaction 和 major compaction，所有的数据在后台都会按规定的次序进行整合。但是一次 major compaction 的过程本质就是一个**多路归并**的过程，即有大量的磁盘读开销，也有大量的磁盘写开销，显然这是一个严重的性能瓶颈。

但是当用户写入的速度始终大于 major compaction 的速度时，就会导致 0 层的文件数量还是不断上升，用户的读取效率持续下降。所以 leveldb 中规定：

- 当 0 层文件数量超过 SlowdownTrigger 时，写入的速度主要减慢；
- 当 0 层文件数量超过 PauseTrigger 时，写入暂停，直至 Major Compaction 完成。

故 compaction 也可以起到平衡读写差异的作用。

##### 整理数据

leveldb 的每一条数据项都有一个版本信息，标识着这条数据的新旧程度。这也就意味着同样一个 key，在 leveldb 中可能存在着多条数据项，且每个数据项包含了不同版本的内容。

为了尽量减少数据集占用磁盘空间的大小，leveldb 在 major compaction 的过程中，对不同版本的数据项进行合并。

##### Minor Compaction

一次 minor compaction 非常简单，其本质就是将一个内存数据库中的所有数据持久化到一个磁盘文件中。每次 minor compaction 结束后，都会生成一个新的 sstable 文件，也就意味着 Leveldb 的版本状态发生了变化，会进行一次版本的更替。有关版本控制的内容，将在最后一节详细介绍。

值得注意的是，minor compaction 是一个时效性要求非常高的过程，要求在其尽可能短的时间内完成，否则就会阻塞正常的写入操作，因此 minor compaction 的优先级高于 major compaction 。当进行 minor compaction 的时候有 major compaction 正在进行时，会首先暂停 major compaction。

![在这里插入图片描述](https://images.gitbook.cn/a60ee0c0-d1ff-11ea-b6c5-2bbaade576df)

##### Major Compaction

相比于 minor compaction, major compaction 就会复杂很多，首先看下一次 major compaction 的示意图。0 层中浅蓝色的三个 sstable 文件，加上 1 层中绿色的 sstable 文件，四个文件进行了合并，输出成两个按序组织的新的 1 层 sstable 文件进行替换。

![在这里插入图片描述](https://images.gitbook.cn/bec79d00-d1ff-11ea-a0b5-393ee992f0f9)

**触发条件**

那么什么时候，会触发 leveldb 进行 major compaction 呢。总结地来说为以下三个条件：

- 当 0 层文件数量超过预定的上限（默认为 4 个）
- 当 level i 层文件的总大小超过 （10 ^ i）MB
- 当某个文件无效读取的次数过多

由于 compaction 的其中一个目的是为了提高读取的效率，因此 leveldb 不允许 0 层存在过多的文件数，一旦超过了上限值，即可以进行 major compaction。

对于 level i（i >= 1）的情况来说，一个读取最多只会访问一个 sstable 文件，因此，本身对于读取效率的影响不会太大。针对于这部分数据发生 compaction 的条件，从提升读取效率转变成了降低 compaction 的 IO 开销。

假设 leveldb 的合并策略只有第一条，那么会导致 1 层文件的个数越来越多或者总的数据量越来越大，而通常一次合并中，0 层文件 key 的取值范围是很大的，导致每一次 0 层文件与 1 层文件进行合并时，1 层文件输入文件的总数据量非常庞大。所以不仅需要控制 0 层文件的个数，同样，每一层文件的总大小同样需要进行控制，使得每次进行 compaction 时，IO 开销尽量保持常量。故 leveldb 规定，1 层文件总大小上限为 10MB，2 层为 100MB，依次类推，最高层（7 层）没有限制。

#### 过程

整个 compaction 可以简单的分为以下几步：

- 寻找合适的输入文件
- 根据 key 重叠情况扩大输入文件集合
- 多路合并
- 积分计算

**寻找输入文件**

不同情况下发起的合并操作，初始输入文件可能不同。对于 level 0 层文件数过多引发的合并场景或由于 level i 层文件总量过大的合并场景，采用轮转的方法选择起始输入文件，记录上一次该层合并的文件的最大 key，下一次就选择此 key 后的首个文件。

**扩大输入文件集合**

![在这里插入图片描述](https://images.gitbook.cn/09d1fb20-d259-11ea-9b53-83a2d03b4f51)

- 红星标注的为起始输入文件；
- 在 level i 层中，查找与起始输入文件有 key 重叠的文件，如图中红线所标注，最终构成 level i 层的输入文件；
- 利用 level i 层的输入文件，在 level i+1 层寻找有 key 重叠的文件，结果为绿线标注的文件，构成 level i、i+1 层输入文件；
- 最后利用两层的输入文件，在不扩大 level i + 1 输入文件的前提下，查询 level i 层的有 key 重叠的文件，结果为蓝线标注文件。

**多路合并**

多路合并的过程比较简单，即将 level i 层的文件，与 level i + 1 层的文件中的数据项，按序整理之后，输出到 level i + 1 层的若干个新文件中，即合并完成。

注意在整理的过程中需要对冗余数据进行清理，同一条数据有多个版本信息，只保留最新的那一份数据。

但是要注意，某些仍然在使用的旧版本的数据，在此时不能立刻删除，等到用户使用结束，释放文件句柄后，根据引用计数来进行清除。

**积分计算**

每一次 compaction 都会消除若干 source 层的旧文件，新增 source + 1 层的新文件，因此触发进行合并的条件状态可能也发生了变化。故在 leveldb 中，使用了计分牌来维护每一层文件的文件个数以及数据总量信息，来挑选出下一个需要进行合并的层数。

计分规则很简单：

- 对于 0 层文件，该层的分数为文件总数 / 4；
- 对于非 0 层文件，该层的分数为文件数据总量 / 数据总量上限。

将得分最高的层数记录，若得分超过 1，则为下一次进行合并的层数。

### 版本控制

Leveldb 每次新生成 sstable 文件，或者删除 sstable 文件，都会从一个版本升级成为另外一个版本。

换句话说，每次 sstable 文件的更替对于 leveldb 来说是一个最小的操作单元，具有原子性。

版本控制对于 leveldb 来说至关重要，是保障数据正确性的重要机制。

#### Manifest

manifest 文件专门用于记录版本信息。leveldb 采用了增量式的存储方式，记录每一个版本相较于上一个版本的变化情况。

一个 manifest 文件中，包含了多条 Session Record。一个 Session Record 记录了从上一个版本至该版本的变化情况。

一个 Manifest 内部包含了若干条 Session Record，其中第一条 Session Record 记载了当时 leveldb 的全量版本信息，其余若干条 Session Record 仅记录每次要更迭的变化情况。因此，每个 manifest 文件的第一条 Session Record 都是一个记录点，记载了全量的版本信息，可以作为一个初始状态进行版本恢复。

![在这里插入图片描述](https://images.gitbook.cn/eabaf390-d262-11ea-8890-675a6c4620cf)

一个  Session Record 可能包含以下字段：

- Comparer 的名称
- 最新的 journal 的文件编号
- 下一个可以使用的文件编号
- 数据库已经持久化数据项最大的 sequence number
- 新增的文件信息
- 删除的文件信息
- compaction 记录信息

#### Commit

每当完成一次 major compaction 整理内部数据或者通过 minor compaction 或者重启阶段的日志重放生成一个 0 层文件，都会触发 leveldb 进行一个版本升级。

一次版本升级的过程如下：

1. 新建一个 session record，记录状态变更信息；
2. 若本次版本更新的原因是由于 minor compaction 或者日志 replay 导致新生成了一个 sstable 文件，则在 session record 中记录新增的文件信息、最新的 journal 编号、数据库 sequence number 以及下一个可以使用的文件编号；
3. 若本次版本更新的原因是由于 major compaction ，则在 session record 中记录新增、删除的文件信息、下
一个可用的文件编号即可；
4. 利用当前的版本信息，加上 session record 的信息，创建一个全新的版本信息。相较于旧的版本信息，
新的版本信息更改的内容为：（1）每一层的文件信息；（2）每一层的计分信息；
5. 将 session record 持久化；
6. 若这是数据库启动后的第一条 session record，则新建一个 manifest 文件，并将完整的版本信息全部记录进 session record 作为该 manifest 的基础状态写入，同时更改 current 文件，将其指向新建的 manifest；
7. 若数据库中已经创建了 manifest 文件，则将该条 session record 进行序列化后直接作为一条记录写入即可；
8. 将当前的 version 设置为刚创建的 version。

![在这里插入图片描述](https://images.gitbook.cn/9058e950-d264-11ea-8a17-f57742cfb5ec)

#### Recover

数据库每次启动时，都会有一个 recover 的过程，简要地来说，就是利用 Manifest 信息重新构建一个最新的 version。

过程如下：

1. 利用 Current 文件读取最近使用的 manifest 文件；
2. 创建一个空的 version，并利用 manifest 文件中的 session record 依次作 apply 操作，还原出一个最新
的 version，注意 manifest 的第一条 session record 是一个 version 的快照，后续的 session record 记录的都是增量的变化；
3. 将非 current 文件指向的其他过期的 manifest 文件删除；
4. 将新建的 version 作为当前数据库的 version。

#### Current

由于每次启动，都会新建一个 Manifest 文件，因此 leveldb 当中可能会存在多个 manifest 文件。因此需要一个额外的 current 文件来指示当前系统使用的到底是哪个 manifest 文件。

![在这里插入图片描述](https://images.gitbook.cn/c62b9910-d264-11ea-b4ad-059a15dc0ed5)

该文件中只有一个内容，即当前使用的 manifest 文件的文件名。

#### 异常处理

倘若数据库中的 manifest 文件丢失，leveldb 是否能够进行修复呢？

答案是肯定的。


当 leveldb 的 manifest 文件丢失时，所有版本信息也就丢失了，但是本身的数据文件还在。因此 leveldb 提供了 Recover 接口供用户进行版本信息恢复，具体恢复的过程如下：

1. 按照文件编号的顺序扫描所有的 sstable 文件，获取每个文件的元数据（最大最小 key），以及最终数据
库的元数据（s equence number 等）；
2. 将所有 sstable 文件视为 0 层文件（由于 0 层文件允许出现 key 重叠的情况，因此不影响正确性）；
3. 创建一个新的 manifest 文件，将扫描得到的数据库元数据进行记录；
但是该方法的效率十分低下，首先需要对整个数据库的文件进行扫描，其次 0 层的文件必然将远远大于 4 个，这将导致极多的 compaction 发生。

##### 附录

Options 重要参数意义：

|  参数选项   | 意义  |
|--|--|
|  BlockCacheCapacity|  系统缓存容量，需要根据你机器的内存情况调节，默认值是 8MiB |
| BlockCacheEvictRemoved                | 是否允许对属于已删除的 "sorted table" 的缓存块启用强制收回。 |
| BlockSize                             | BockSize 是每个 "sorted table"  的最小未压缩大小（以字节为单位），默认为 4KiB |
| BlockRestartInterval                  |               key 编码中重新写入一个完整 key 的之间的 key 的数量，默认为 16                                               详细可参见（SStable 文件格式-DataBlock 格式）|
| CompactionL0Trigger                   |                 level 0 上触发 compaction 的阈值                                             |
| CompactionTableSize                   |                     CompactionTableSize 限制压缩生成的 "sorted table" 的大小。                                         |
| CompactionTotalSize                   |                    CompactionTableSize 限制某一个 level 上压缩生成的 "sorted table" 的总大小                                          |
| DisableBufferPool                     |                        是否开启缓冲池                                      |
| DisableBlockCache                     |                         是否开启 blockcache                                     |
| DisableLargeBatchTransaction          |                     DisableLargeBatchTransaction 允许在大批量写入时禁用切换到事务模式。如果启用大于 WriteBuffer 的批量写入，则将使用事务。                                         |
| ErrorIfExist                          |                        是否应该返回 DB 中发生的错误                                      |
| NoSync                                |                          是否关闭 fsync                                    |
| NoWriteMerge                          |                        是否关闭写合并的功能                                     |
| OpenFilesCacheCapacity                |                  打开文件句柄缓存的容量                                            |
| ReadOnly                              |                      系统是否只读                                        |
| WriteBuffer                           |                写入缓存大小，也就是 memdb 的最大 size，默认为 4MiB，超过这个大小，会被刷盘生成 L0 层的 " sorted table " 文件                                              |
| WriteL0PauseTrigger                   |              L0 层写多少的 sorted table 文件后禁止继续写入，默认值为 12                                                |
| WriteL0SlowdownTrigger                |                    L0 层写多少的 sorted table 文件后开始放缓写入，默认值是 8                                          |

如果你觉得有帮助，可以链接看源文章支持一下 ～ >< ～ , 感谢

[https://gitbook.cn/gitchat/activity/5f0ddd67425b19297a0b96ce](https://gitbook.cn/gitchat/activity/5f0ddd67425b19297a0b96ce)

----------
本文首发于 GitChat，未经授权不得转载，转载需与 GitChat 联系。

