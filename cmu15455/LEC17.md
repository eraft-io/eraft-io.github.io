# Lecture 17: Two-Phase Locking  两阶段锁协议

## Transaction Locks

The DBMS contains a centralized lock manager that decides decisions whether a transaction can have a lock or not. It has a global view of whats going on inside the system.

数据库管理系统包含一个集中的锁管理器，它决定事务是否可以有锁。并且对系统内部发生的事情有一个全局的视图。

- Shared Lock (S-LOCK): A lock that allows multiple transactions to read the same object at the same time. If one transaction holds a shared lock, then another transaction can also acquire that same shared lock.

- 共享锁（S锁）：它允许多个事务同时读取同一个对象的锁。如果一个事务持有共享锁，那么另一个事务也可以获取相同的共享锁。

- Exclusive Lock (X-LOCK): Allows a transaction to modify an object. This lock is not compatible for any other lock. Only one transaction can hold an exclusive lock at a time.

- 独占锁（X锁）：允许事务修改对象。这个锁不与任何其他的锁兼容，并且一次只能有一个事务持有该锁。

Executing with locks:

使用锁来执行事务的流程：

1. Transactions request locks (or upgrades) from the lock manager.

1. 事务从锁管理器获取锁

2. The lock manager grants or blocks requests based on what locks are currently held by other transactions.

2. 锁管理器根据其他事务当前持有的锁来控制当前请求是应该被阻塞住还是继续执行

3. Transactions release locks when they no longer need them.

3. 事务在不在需要锁的时候释放它持有的锁

4. The lock manager updates its internal lock-table and then gives locks to waiting transactions.

4. 锁管理器更新其内部锁表，然后为正在等待的事务提供锁

# Two-Phase Locking  两阶段锁协议

Two-Phase locking (2PL) is a pessimistic concurrency control protocol that determines whether a transaction is allowed to access an object in the database on the fly. The protocol does not need to know all of the queries that a transaction will execute ahead of time.

两阶段锁定（2PL）是一种悲观的并发控制协议，用于确定是否允许事务动态的访问数据库中的对象。该协议不需要提前知道事务将执行的所有查询。

Phase 1: Growing

阶段1：增长，增加锁的持有

• Each transaction requests the locks that it needs from the DBMS’s lock manager.

• 每个事务都向 DBMS 的锁管理器请求它需要的锁

• The lock manager grants/denies lock requests.

• 锁管理器授予/拒绝锁请求

Phase 2: Shrinking

阶段 2：收缩，释放锁的持有

• The transaction enters this phase immediately after it releases its first lock.

• 事务在释放第一个锁后立即进入此阶段

• The transaction is allowed to only release locks that it previously acquired. It cannot acquire new locks in this phase.

• 事务只允许释放它之前获得的锁，在这个阶段它不能获取新的锁

On its own, 2PL is sufficient to guarantee conflict serializability. It generates schedules whose precedence graph is acyclic. But it is susceptible to cascading aborts, which is when a transaction aborts and now another transaction must be rolled back, which results in wasted work.

就其本身而言，2PL 足以保证冲突的可串行化。它生成优先级图是非循环的调度。但是它容易受到级联中止的影响，即当一个事务出现中止的时候宁一个事务也必须回滚，这会导致很多任务白做了。

There are also potential schedules that are serializable but would not be allowed by 2PL (locking can limit concurrency).

有一些潜在的调度室可序列化的，但是 2PL 不允许（锁会限制并发）

## Strong Strict Two-Phase Locking  严格的两阶段锁定

Strong Strict 2PL (SSPL, also known as Rigorous 2PL) is a variant of 2PL where the transaction only releases locks when it finishes. A schedule is strict if a value written by a transaction is not read or overwritten by other transactions until that transaction finishes. Thus, there is not a shrinking phase in SS2PL like in regular 2PL.
Strong Strict 2PL (SSPL，也被称为  Rigorous 2PL) 是 2PL 的变体，其中事务只有在完成的时候才释放锁。如果一个事务写入的值在该事务完成之前不会被其他事务读取或者覆盖，则是调度严格的。相比于常规 2PL，Strong Strict 2PL 没有收缩阶段。

The advantage of this approach is that the DBMS does not incur cascading aborts. The DBMS can also reverse the changes of an aborted transaction by just restoring original values of modified tuples.

这种方法的有点是 DBMS 不会导致级联中止。DBMS 还可以通过仅恢复已修改的元组的原始值来反转已中止事务的修改。

## 2PL Deadlock Handling  2PL 死锁处理

A deadlock is a cycle of transactions waiting for locks to be released by each other. There are two approaches to handling deadlocks in 2PL: detection and prevention.

死锁是事务之间循环等待对方释放锁，在 2PL 中有两处理死锁的方法：检测和预防。

### Approach 1: Deadlock Detection  方法 1: 死锁检测

The DBMS creates a waits-for graph: Nodes are transactions, and edge from Ti to Tj if transaction Ti is waiting for transaction Tj to release a lock. The system will periodically check for cycles in waits-for graph and then make a decision on how to break it.

DBMS 创建一个等待图：节点是事务，如果事务 Ti 正等待事务 Tj 释放锁，可以用途中的边来表示。系统将定期的检查等待图中的环，然后决定如何去打破它。

• When the DBMS detects a deadlock, it will select a “victim” transaction to rollback to break the cycle.

• 当 DBMS 检测到死锁时，它会选择一个 “受害者” 事务来回滚以打破循环。

• The victim transaction will either restart or abort depending on how the application invoked it

• 受害者事务将重新启动或中止，具体怎么做取决于应用程序调用它的方式

• There are multiple transaction properties to consider when selecting a victim. There is no one choice that is better than others. 2PL DBMSs all do different things:

选择受害者的时候需要考虑多个事务属性，没有一冲选择比其他的要更好。2PL DBMS都做着不同的事情：

1. By age (newest or oldest timestamp).

1. 事务的年龄，哪个执行的久

2. By progress (least/most queries executed).

2. 进度，更多的查询执行

3. By the # of items already locked.

3. 已经被加锁的 item 数量

4. By the # of transactions that we have to rollback with it.

4. 中止这个事务五门需要回滚的事务数量

5. of times a transaction has been restarted in the past

5. 事务在过去被重启的次数

• Rollback Length: After selecting a victim transaction to abort, the DBMS can also decide on how far to rollback the transaction’s changes. Can be either the entire transaction or just enough queries to break the deadlock.

• 回滚的长度：选择要中止的受害者事务后，DBMS1还可以决定回滚事务更改的程度。可以是整个事务，也可以是足以打破死锁的某些查询。

### Approach 2: Deadlock Prevention  死锁预防

When a transaction tries to acquire a lock, if that lock is currently held by another transaction, then perform some action to prevent a deadlock. Assign priorities based on timestamps (e.g., older means higher priority). These schemes guarantee no deadlocks because only one type of direction is allowed when waiting for a lock. When a transaction restarts, its
(new) priority is its old timestamp.

当一个事务试图获取一个锁的时候，如果该锁当前被另一个事务持有，那么执行一些操作来防止死锁。根据时间戳来分配优先级（例如：越旧意味着更高的优先级）。这些方案保证了没有死锁，因为在等待锁的时候只允许一种类型的方向。当一个事务重新启动时，它的优先级是它的旧时间戳。

• Wait-Die (“Old waits for Young”): If T1 has higher priority, T1 waits for T2. Otherwise T1 aborts

• Wait-Die（“Old 等待 Young”）：如果 T1 具有更高的优先级，则 T1 等待 T2. 否则 T1 中止

• Wound-Wait (“Young waits for Old”): If T1 has higher priority, T2 aborts. Otherwise T1 waits.

• Wound-Wait （“Young 等待 Old”）: 如果 T1 具有更高的优先级，则 T2 中止。否则 T1 等待。

## Lock Granularities   锁粒度

If a transaction wants to update one billion tuples, it has to ask the DBMS’s lock manager for a billion locks. This will be slow because the transaction has to take latches in the lock manager’s internal lock table data structure as it acquires/releases locks.

如果一个事务想要更新十亿个元组，它必须向 DBMS 的锁管理器请求十亿个锁。这样会很慢，因为事务在获取/释放锁的时候必须在锁管理器的内部锁表数据结构中获取锁存器

To avoid this overhead, the DBMS can use to use a lock hierarchy that allows a transaction to take more coarse-grained locks in the system. For example, it could acquire a single lock on the table with one billion tuples instead of one billion separate locks. When a a transaction acquires a lock for an object in this hierarchy, it implicitly acquires the locks for all its children.

为了避免这种开销，DBMS 可以使用锁层次结构，允许事务在系统中使用更粗粒度的锁。例如，它可以在具有十亿个元组的表上获取单个锁，而不是十亿个单独的锁。当一个事务为这个层次结构中的一个对象获取一个锁时，它会隐式的为它的所有子对象获取锁

Intention locks allow a higher level node to be locked in shared or exclusive mode without having to check all descendant nodes. If a node is in an intention mode, then explicit locking is being done at a lower level in the tree.

意向锁允许将更高级别的节点锁定为共享或者独占模式，而无需检查所有的后代节点。如果节点处于意向模式，则显示锁定在树中的较低级别完成

• Intention-Shared (IS): Indicates explicit locking at a lower level with shared locks.

• Intention-Shared (IS): 表示使用共享锁在较低的级别显示锁定

• Intention-Exclusive (IX): Indicates explicit locking at a lower level with exclusive or shared locks.

• Intention-Exclusive (IX): 表示具有排他或共享锁的较低级别的显示锁定

• Shared+Intention-Exclusive (SIX): The sub-tree rooted at that node is locked explicitly in shared mode and explicit locking is being done at a lower level with exclusive-mode locks.

• Shared+Intention-Exclusive (SIX): 以该节点为根的子树在共享模式下显示锁定，并且显示锁定在较低的级别使用独占模式锁定完成

## Conclusion   结论

2PL is used in most DBMSs that support transactions. The protocol automatically provides correct interleavings of transaction operations, but it requires additional steps to handle deadlocks.

2PL 用于大多数支持事务的 DBMS。该协议自动提供正确的事务操作交错，但是它需要额外的步骤来处理死锁

The application does not typically set locks manually using SQL. The DBMS acquires the locks automatically before a query accesses or modifies an object. But sometimes the application can provide the DBMS with hints to help it improve concurrency:

应用程序通常不使用 SQL 手动设置锁。DBMS 在查询访问或修改对象之前自动获取锁。但有时应用程序可以为 DBMS 提供提示以帮助它提高并发性：

SELECT...FOR UPDATE: Perform a select and then sets an exclusive lock on fetched tuples

SELECT...FOR UPDATE: 执行选择，然后在获取的元组上设置排他锁
