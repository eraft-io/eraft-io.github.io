# Lecture 20: Logging Schemes   日志记录方案

## Crash Recovery  崩溃恢复

Recovery algorithms are techniques to ensure database consistency, transaction atomicity, and durability despite failures. DBMS is divided into different components based on the underlying storage device. We must also classify the different types of failures that the DBMS needs to handle.

恢复算法是在故障时确保数据库的一致性、事务的原子性以及持久性的技术。DBMS 根据底层存储设备分为不同的组件。我们还必须对 DBMS 需要处理对的不同类型的故障进行分类。


Every recovery algorithm has two parts:
每个恢复算法都有两个部分：

• Actions during normal transaction processing to ensure that the DBMS can recover from a failure.

正常事务处理期间的操作，以确保 DBMS 可以从失败中恢复。

• Actions after a failure to to recover the database to a state that ensures atomicity, consistency, and durability.

失败后的操作：用来将数据库恢复到确保原子性、一致性和持久性的状态。

The key primitives that we are going to use in a recovery algorithm are UNDO and REDO. Not all algorithms use both of these:

我们将在恢复算法中使用到关键的原语是 UNDO 和 REDO，并非所有算法都使用这两种方法：

• UNDO: The process of removing the effects of an incomplete or aborted transaction.

UNDO：消除不完整或者中止事务影响的处理过程

• REDO: The process of re-instating the effects of a committed transaction for durability.

REDO：为了持久性而重新执行已提交事务的效果的处理过程

## Failure Classification  故障分类

### Type 1: Transaction Failures  事务失败

- Logical Errors: A transaction cannot complete due to some internal error condition (e.g., integrity, constraint violation).

逻辑错误：由于某些内部错误条件（例如：完整性、违反约束条件），事务无法执行完成

- Internal State Errors: The DBMS must terminate an active transaction due to an error condition (e.g., deadlock)

内部状态错误：由于错误条件（例如：死锁），DBMS 必须终止一个运行中的事务

### Type 2: System Failures  系统故障

- Software Failure: There is a problem with the DBMS implementation (e.g. uncaught divide-by-zero exception) and the system has to halt.

软件的故障：DBMS 的实现存在问题（例如：没有捕获除以 0 的异常），系统必须终止。

- Hardware Failure: The computer hosting the DBMS crashes. We assume that non-volatile storage contents are not corrupted by system crash.

硬件故障：托管 DBMS 的计算机崩溃。我们假设非易失性存储的内容不会因系统崩溃而损坏

### Type 3: Storage Media Failure  存储介质故障了

- Non-Repairable Hardware Failure: A head crash or similar disk failure destroys all or parts of non-volatile storage. Destruction is assumed to be detectable. No DBMS can recover from this. Database must be restored from archived version

不可修复的硬件故障：磁头崩溃或者类似的磁盘故障会破坏全部或者部分非易失性存储。假设破坏是可以检测的。没有DBMS可以从中恢复。必须从存档的版本恢复数据库。


## Buffer Pool Management Policies  缓冲池管理策略

Steal Policy: Whether the DBMS allows an uncommitted transaction to overwrite the most recent committed value of an object in non-volatile storage (can a transaction write uncommitted changes to disk).

窃取策略：DBMS 是否允许未提交的事务覆盖非易失性存储中对象的最新提交值（事务是否可以将未提交的更改写入磁盘）。

• STEAL: is allowed
• NO-STEAL: is not allowed.

Force Policy: Whether the DBMS ensures that all updates made by a transaction are reflected on non-volatile storage before the transaction is allowed to commit

强制策略：DBMS 是否确保在允许提交事务之前，事务所做的所有更新都反映在非易失性存储上

• FORCE: Is enforced
• NO-FORCE: Is not enforced

Force writes makes it easier to recover but results in poor runtime performance.

强制写入更容易恢复，但是会导致运行时性能不佳

Easiest System to implement: NO-STEAL + FORCE

最容易实现的系统：NO-STEAL + FORCE

• The DBMS never has to undo changes of an aborted transaction because the changes were not written to disk.

DBMS 永远不必撤销中止事务的更改，因为更改没有写入磁盘。

• It also never has to redo changes of a committed transaction because all the changes are guaranteed to be written to disk at committed.

它也永远不必重做已经提交的事务更改，因为所有的更改都保证在提交时写入磁盘

• Limitation: If all of the data that a transaction needs to modify does not fit on memory, then that transaction cannot execute because the DBMS is not allowed to write out dirty pages to disk before the transaction commits.

限制：如果一个事务需要修改的所有数据都不适合内存，那么该事务将无法执行，因为不允许 DBMS 在事务提交之前将将脏页写出到磁盘

## Shadow Paging    影子分页

The DBMS maintains two separate copies of the database (master, shadow). Updates are only made in the shadow copy. When a transaction commits, atomically switch the shadow to become the new master. This is an example of a NO-STEAL + FORCE system.

DBMS 维护数据库的两个独立副本（主副本、影子副本）。仅在影子副本中进行更新，当事务提交时，原子的切换影子副本成为新的 master. 这是一个 NO-STEAL + FORCE 系统的例子


Implementation:

• Organize the database pages in a tree structure where the root is a single disk page.

以树结构组织数据库页面，其中根是单个磁盘页面

• There are two copies of the tree, the master and the shadow:

树存在两个副本，主副本和影子副本

– The root points to the master copy

根指向主副本

– Updates are applied to the shadow copy

更新应用于影子副本

• To install updates, overwrite the root so it points to the shadow, thereby swapping the master and shadow.

要安装更新，覆盖根节点指向影子页面，从而交换主目录和影子

Before overwriting the root, none of the transactions updates are part of the disk-resident database.

在覆盖根之前，所有的事务更新都还不是磁盘上数据库的一部分

After overwriting the root, all of the transactions updates are part of the disk resident database.

覆盖根之后，所有的事务更新都是磁盘数据库上的一部分了

• UNDO: Remove the shaduow pages. Leave master and the DB root pointer alone

• UNDO: 删除影子页面，不理会 master 以及 db 根指针

• REDO: Not needed at all

• REDO: 不需要


## Write-Ahead Logging

The DBMS records all the changes made to the database in a log file (on stable storage) before the change is made to a disk page. The log contains sufficient information to perform the necessary undo and redo   
actions to restore the database after a crash. This is an example of a STEAL + NO-FORCE system.

在对磁盘页面进行更改之前，DBMS 会将数据库所做的所有更改记录到一个日志文件中（存储在稳定存储器上）。这个日志包含了足够的信息来执行必要的撤销和重做操作以便在系统崩溃后恢复数据库。这是一个 STEAL + NO-FORCE 系统的例子

Almost every DBMS uses write-ahead logging (WAL) because it has the fastest runtime performance. But the DBMS’s recovery time with WAL is slower than shadow paging because it has to replay the log.

几乎每个 DBMS 都使用预写日志（WAL），因为它具有最快的运行时性能。但是 DBMS 使用 WAL 的恢复时间比影子分页慢，因为它必须重放日志。

Implementation:

实现：

- All log records pertaining to an updated page are written to non-volatile storage before the page itself is allowed to be overwritten in non-volatile storage.

在页面本身被允许在非易失性存储中覆盖之前，与更新页面有关的所有日志记录都被写入非易失性存储。

- A transaction is not considered committed until all its log records have been written to stable storage.

- 在所有日志记录都写入稳定存储之前，不会认为事务已经提交

When the transaction starts, write a <BEGIN> record to the log for each transaction to mark its starting point.

当事务开始的时候，为每个事务写入一个 <BEGIN> 的记录到日志中，以标记它的起始点

• When a transaction finishes, write a <COMMIT> record to the log and make sure all log records are flushed before it returns an acknowledgment to the application.


• Each log entry contains information about the change to a single object: 

– Transaction ID.
– Object ID.
– Before Value (used for UNDO). 
– After Value (used for REDO).

• Log entries to disk should be done when transaction commits. You can use group commit to batch multiple log flushes together to amortize overhead.

## Checkpoints

The main problem with write-ahead logging is that the log file will grow forever. After a crash, the DBMS has to replay the entire log, which can take a long time if the log file is large. Thus, the DBMS can periodically takes a checkpoint where it flushes all buffers out to disk.

How often the DBMS should take a checkpoint depends on the application’s performance and downtime requirements. Taking a checkpoint too often causes the DBMS’s runtime performance to degrade. But waiting a long time between checkpoints can potentially be just as bad, as the system’s recovery time after a restart increases.

### Blocking Checkpoint Implementation:

• The DBMS stops accepting new transactions and waits for all active transactions to complete. 

• Flush all log records and dirty blocks currently residing in main memory to stable storage.

• Write a <CHECKPOINT> entry to the log and flush to stable storage.

## Logging Schemes

Physical Logging:

• Record the changes made to a specific location in the database 

• Example: Position of a record in a page

Logical Logging:

Record the high level operations executed by transactions. Not necessarily restricted to single page. Requires less data written in each log record than physical logging. Difficult to implement recovery with logical logging if you have concurrent transactions in a non-deterministic concurrency control scheme.

• Example: The UPDATE, DELETE, and INSERT queries invoked by a transaction.

Physiological Logging:


• Hybrid approach where log records target a single page but do not specify data organization of the page.

• Most commonly used approach.
