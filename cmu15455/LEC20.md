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

以树结构组织数据库页面，其中根时单个磁盘页面

• There are two copies of the tree, the master and the shadow:

– The root points to the master copy

– Updates are applied to the shadow copy

• To install updates, overwrite the root so it points to the shadow, thereby swapping the master and shadow.

Before overwriting the root,none of the transactions updates are part of the disk-resident database.

After overwriting the root, all of the transactions updates are part of the disk resident database.

• UNDO: Remove the shadow pages. Leave master and the DB root pointer alone

• REDO: Not needed at all

