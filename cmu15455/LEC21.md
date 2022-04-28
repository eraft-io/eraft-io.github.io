# Lecture 21: ARIES Database Crash Recovery Algorithms

# ARIES 数据库崩溃恢复算法

## ARIES

Algorithms for Recovery and Isolation Exploiting Semantics. Developed at IBM research in early 1990s.
Not all systems implement ARIES exactly as defined in the original paper, but they are similar enough.

利用语义恢复和隔离算法，于 1990 年代初在 IBM 研究中开发。并非所有的系统都完全按照原始论文中的定义去实现 ARIES，但是它们实现都很类似。

Main ideas of the ARIES recovery protocol:

ARIES 恢复协议的主要思想：

- Write Ahead Logging: Any change is recorded in log on stable storage before the database change is written to disk (STEAL + NO-FORCE).

预写日志记录：在将数据库更改写入磁盘之前，任何的修改都会被记录在稳定存储上的日志中 （STEAL + NO-FORCE）

- Repeating History During Redo: On restart, retrace actions and restore database to exact state before crash.

- 重做期间重新执行历史操作： 重新启动的时候，回溯操作将数据库恢复到崩溃前的状态

- Logging Changes During Undo: Record undo actions to log to ensure action is not repeated in the event of repeated failures.

- 在撤销期间记录更改：将撤销操作记录到日志中，以确保在重复失败的情况不会重复操作

## WAL Records  WAL 记录

We need to extend the DBMS’s log record format to include additional info. Every log record now includes a globally unique log sequence number (LSN). Various components in the system keep track of LSNs that pertain to them:

我们需要扩展 DBMS 的日志记录格式以包含附加信息。每个日志记录中都包含一个全局唯一的日志序列号（LSN）。系统中的各个组件都会追踪与其相关的 LSN:

- Each data page contains a pageLSN: The LSN of the most recent update to that page.

- 每个数据页面都包含一个 pageLSN: 该页最近更新的 LSN

- System keeps track of flushedLSN: The max LSN flushed so far

- 系统跟踪的 flushedLSN: 到目前为止已经执行刷盘操作的最大 LSN

- Before page i can be written to disk, we must flush log at least to the point where pageLSN i ≤ flushedLSN

- 在第 i 页可以被写入磁盘之前，我们必须至少将日志刷新到 pageLSN i <= flushedLSN

## Normal Execution

We first discuss the steps that the DBMS takes at runtime while it executes transactions.

我们首先讨论在 DBMS 运行时执行事务的时候所采取的步骤

Transaction Commit

事务提交

When a transaction goes to commit, the DBMS first writes COMMIT record to log buffer in memory. Then the DBMS flushes all log records up to and including the transaction’s COMMIT record to disk. Note that these log flushes are sequential, synchronous writes to disk.

当事务提交的时候，DBMS 首先将 COMMIT 记录写入到内存中的日志缓冲区。然后 DBMS 将所有日志记录刷新到磁盘，包括事务的 COMMIT 记录。注意这里的日志刷新时对磁盘顺序、同步的写入

Once the COMMIT record is safely stored on disk, the DBMS returns an acknowledgment back to the application that the transaction has committed. At some later point, the DBMS will write a special TXN-END record to log. This indicates that the transaction is completely finished in the system and there will not be anymore log records for it. These TXN-END records are used for internal bookkeeping and do not need to be flushed immediately.

一旦 COMMIT 记录安全地存储在磁盘上，DBMS 就会向应用返回一个事务已提交的确认。稍后，DBMS 将写入一个特殊的 TXN-END 记录到日志中。这表明事务在系统中已完全完成，不会再有任何后续的日志记录。这些 TXN-END 记录用于内部记录，不需要立即刷新。


Transaction Abort

事务中断

Aborting a transaction is a special case of the ARIES undo operation applied to only one transaction.

中止事务是仅适用于一个事务的 ARIES 撤销操作的一种特殊情况

We need to add another field to our log records called the prevLSN. This corresponds to the previous LSN for the transaction. The DBMS uses these prevLSNs to maintain a linked-list for each transaction that makes it easier to walk through the log to find its records.

我们需要在我们的日志记录中添加另一个字段，称为 prevLSN. 这对应于事务先前的 LSN. DBMS 适用这些 prevLSN 为每个事务维护一个链表，以便轻松的遍历日志查找对应的记录

We also need to introduce a new type of record called the compensation log record (CLR). A CLR describes the actions taken to undo the actions of a previous update record. It has all the fields of an update log record plus the undoNext pointer (i.e., the next-to-be-undone LSN). The DBMS adds CLRs to the log like any other record but they never need to be undone.

我们还需要引入一种称为补偿日志记录（CLR）的新型记录。CLR 描述了为撤销先前更新记录的操作而采取的操作。它具有更新日志记录所有字段以及 undoNext 指针（即下一个要撤销的 LSN）. DBMS 像其他记录一样将 CLR 添加到日志中，但是它们永远不需要被撤销。

To abort a transaction, the DBMS first appends a ABORT record to the log buffer in memory. It then undoes the transaction’s updates in reverse order to remove their effects from the database. For each undone update, the DBMS creates CLR entry in the log and restore old value. After all of the aborted transaction’s updates are reversed, the DBMS then writes a TXN-END log record.

要中止事务，DBMS 首先需要将 ABORT 记录追加到内存中的日志缓冲区。然后它们以相反的顺序撤销事务的更新，以从数据库中删除它们的影响。对于每个撤销的更新，DBMS 在日志中创建 CLR 条目并恢复其旧值。在所有已中止的事务更新全部都被回滚以后，DBMS 将写入一个 TXN-END 的日志记录


## Checkpointing  

The DBMS periodically takes checkpoints where it writes the dirty pages in its buffer pool out to disk. This is used to minimize how much of the log it has to replay upon recovery.

DBMS 定期的获取检查点，将缓冲区中的脏页写入磁盘。它的作用是最小化恢复时必须重播的日志量
 
We first discuss two blocking checkpoint methods where the DBMS pauses transactions during the checkpoint process. This pausing is necessary to ensure that the DBMS does not miss updates to pages during the checkpoint. We then present a better approach that allows transactions to continue to execute during the checkpoint but requires the DBMS to record additional information to determine what updates it may have missed.

我们首先讨论两种阻塞创建检查点的方法，其中DBMS在创建检查点过程中需要暂停事务。这种暂停是必要的，以确保 DBMS 在创建检查点的期间不会丢失对页面的更新操作。我们有提出了一种更好的方法，允许事务在创建检查点期间继续执行，但是需要 DBMS 存储附加的信息以确定它可能错过的更新操作

### Blocking Checkpoints

The DBMS halts everything when it takes a checkpoint to ensure that it writes a consistent snapshot of the database to disk. The is the same approach discussed in previous lecture:

DBMS 在创建检查点的时候会暂停所有的操作，以确保将数据库的一致性快照写入到磁盘中。这与上一将中讨论的方法相同：

• Halt the start of any new transactions.

停止任何新事物的开始

• Wait until all active transactions finish executing.

等所有活动中的事务都执行完成

• Flush dirty pages on disk.

刷新磁盘上的脏页


### Slightly Better Blocking Checkpoints

更好的阻塞式检查点创建

Like previous checkpoint scheme except that you the DBMS does not have to wait for active transactions to
finish executing. We have to now record internal system state as of the beginning of the checkpoint.

与之前创建检查点的方案类似，只是 DBMS 不必等待所有活动的事务完成执行。我们必须记录创建检查点开始时内部的系统状态

• Halt the start of any new transactions.

停止任何新事物的开始

• Pause transactions while the DBMS takes the checkpoint

在DBMS执行检查点的时候暂停事务

Active Transaction Table (ATT): The ATT represents the state of transactions that are actively running in the DBMS. A transaction’s entry is removed after the DBMS completes the commit/abort process for that transaction. For each transaction entry, the ATT contains the following information:

活动事务表（ATT）: ATT 表示在 DBMS 中正在运行的事务的状态，在 DBMS 完成该事务提交 / 中止过程之后，将删除该事务的条目。对于每个事务条目，ATT 包含以下信息：

• transactionId: Unique transaction identifier

事务 ID：事务的唯一标识

• status: the current “mode” of the transaction (Running, Committing, Undo candidate)

状态：事务当前的模式 （运行中，提交中，撤销候选）

• lastLSN: Most recent LSN written by transaction

lastLSN：事务写入最新的 LSN

Dirty Page Table (DPT): The DPT contains information about the pages in the buffer pool that were modified by uncommitted transactions. There is one entry per dirty page containing the recLSN (i.e., the LSN of the log record that first caused the page to be dirty).

脏页表（DPT）: DPT 包含有关缓冲池中由未提交事务修改的页面信息。每个脏页由一个条目包含 （recLSN）- 即，首先导致页面变脏的日志记录的 LSN

### Fuzzy Checkpoints  模糊检查点

A fuzzy checkpoint is where the DBMS allows other transactions to continue to run. This is what ARIES uses in its protocol.

模糊检查点是DBMS允许其他事务继续运行的地方，这是 ARIES 在其协议中使用的内容

The DBMS uses additional log records to track checkpoint boundaries:

DBMS 使用额外的日志记录来跟踪检查点边界

• <CHECKPOINT-BEGIN>: Indicates the start of the checkpoint.

• <CHECKPOINT-BEGIN>: 表示检查点的开始

• <CHECKPOINT-END>: When the checkpoint has completed. It contains the ATT + DPT.

• <CHECKPOINT-END>: 检查点创建完成时。它包含了 ATT + DPT

## ARIES Recovery   ARIES 恢复

The ARIES protocol is comprised of three phases. Upon start-up after a crash, the DBMS will execute the following phases:

ARIES 协议由三个阶段组成。在崩溃后启动时，DBMS 将执行以下阶段：

1. Analysis: Read the WAL to identify dirty pages in the buffer pool and active transactions at the time of the crash.

分析：读取 WAL 以识别崩溃时缓冲池中脏页和活动的事务

2. Redo: Repeat all actions starting from an appropriate point in the log.

重做：在日志中的适当点开始重复所有操作

3. Undo: Reverse the actions of transactions that did not commit before the crash.

撤销：撤销在崩溃前没有提交的事务的操作

### Analysis Phase  分析阶段

Start from last checkpoint found via the database’s MasterRecord LSN.

从数据库的  MasterRecord LSN 找到最后一个检查点开始

• Scan log forward from the checkpoint.

从检查点向前扫描日志

• If the DBMS finds a TXN-END record, remove its transaction from ATT.

如果 DBMS 找到一条 TXN-END 记录，则从 ATT 中删除其事务

• All other records, add transaction to ATT with status UNDO, and on commit, change transaction status to COMMIT.

所有其他记录，将事务添加到状态为 UNDO 的 ATT, 并在提交时将事务状态改为 COMMIT

• For UPDATE log records, if page P is not in the DPT, then add P to DPT and set P’s recLSN to the log record’s LSN.

对于 UPDATE 的日志记录，如果页面 P 不在 DPT 中，则将 P 添加到 DPT 中并将  P 的 recLSN 设置为日志记录的 LSN


### Redo Phase 重做阶段

The goal is to repeat history to reconstruct state at the moment of the crash. Reapply all updates (even aborted transactions) and redo CLRs.

目标是重复历史操作以重建崩溃时候的状态，重新 APPLY 所有的更新并重做 CLR

The DBMS scans forward from log record containing smallest recLSN in the DPT. For each update log record or CLR with a given LSN, the DBMS re-applies the update unless:

DBMS 从 DPT 中包含最小的 recLSN 的日志记录开始向前扫描，对于具有给定 LSN 的每个更新日志记录或者 CLR ，DBMS 会重新应用更新操作，除非：

• Affected page is not in the DPT, or

受影响的页面不在 DPT 中，或者

• Affected page is in DPT but that record’s LSN is greater than smallest recLSN, or

受影响的页面在 DPT 中，但是该记录的 LSN 大于最小的 recLSN, 或者

• Affected pageLSN (on disk) ≥ LSN.

受影响的 pageLSN > LSN

To redo an action, the DBMS re-applies the change in the log record and then sets the affected page’s pageLSN to that log record’s LSN.

要重做操作，DBMS 重新应用日志记录中的更改，然后将受影响的页面的 pageLSN 设置为该日志记录的 LSN

At the end of the redo phase, write TXN-END log records for all transactions with status COMMIT and remove them from the ATT.

在重做阶段结束时，为所有状态为 COMMIT 的事务写入 TXN-END 日志记录，并将它们从 ATT 中删除

### Undo Phase  撤销阶段

In the last phase, the DBMS reverses all transactions that were active at the time of crash. These are all transactions with UNDO status in the ATT after the Analysis phase.

在最后一个阶段，DBMS 会回滚所有崩溃时处于活动状态中的所有事务。这些都是在分析阶段之后在 ATT 中有 UNDO 状态的事务

The DBMS processes transactions in reverse LSN order using the lastLSN to speed up traversal. As it reverses the updates of a transaction, the DBMS writes a CLR entry to the log for each modification.

DBMS 使用 lastLSN 以反转 LSN 顺序处理事务以加快遍历速度，当它反向的遍历事务更新时，DBMS 会为每次修改写入一个 CLR 条目到日志中 

Once the last transaction has been successfully aborted, the DBMS flushes out the log and then is ready to start processing new transactions.

一旦最后一个事务成功中止，DBMS 就会刷新日志，然后准备开始处理新的事务

