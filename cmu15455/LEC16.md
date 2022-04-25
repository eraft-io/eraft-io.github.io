# Concurrency Control Theory   并发控制原理

## Transactions 事务

A transaction is the execution of a sequence of one or more operations (e.g., SQL queries) on a shared database to perform some higher level function. They are the basic unit of change in a DBMS. Partial transactions are not allowed.

事务是在共享数据库上执行的一系列一个或者多个操作（例如 SQL 查询）, 以执行更高级别的功能。它们是数据库管理系统中基本的单位，它不允许被不完全的实现。

Example: Move $100 from Andy’s bank account to his bookie’s account

例如：从安迪的银行账户中转移出 $100 到他的博彩账户


1 Check whether Andy has $100.

检查 Andy 是否有 $100

2 Deduct $100 from his account.

从他的账户中扣除 $100


3 Add $100 to his bookie’s account.

在他的博彩账户上加上 $100

Executing concurrent transactions in a DBMS is challenging. It is difficult to ensure correctness while also executing transactions quickly. We need formal correctness criteria:

在数据库管理系统上并发的执行事务是很有挑战的事情。在快速执行事务的过程中很难保证正确性。我们需要正式的正确性准则。

• Temporary inconsistency is allowed.

允许暂时不一致

• Permanent inconsistency is bad.

永久的不一致是不好的。

The scope of a transaction is only inside the database. It cannot make changes to the outside world because it cannot roll those back.

事务的作用域仅在数据库系统内部，它无法逆转系统外部的变更。

## Definitions  定义

A database is a set of named data objects (A, B, C, ..). A transaction is a sequence of read and write operations (R(A), W(B)).

数据库由一个对象集合组成 (A, B, C)，事务是针对这些对象的一系列读写操作 (R(A), W(B))。

The outcome of a transaction is either COMMIT or ABORT.

事务的执行结果是提交或者终止。

- If COMMIT, all of the transaction’s modifications are saved to the database.

- 一旦事务提交，所有的事务修改都会被存储到数据库中。

- If ABORT, all of the transaction’s changes are undone so that it is like the transaction never happened. Aborts can be either self-inflicted or caused by the DBMS.

- 如果中止，事务所有的更改都将撤销，就好像事务从未发生过一样。事务的中止可以是用户自己造成的，也可以是 DBMS 内部引起的。

Correctness Criteria: ACID

保证事务正确性定义的标准：ACID


- Atomicity: All actions in the transaction happen, or none happen. “All or Nothing”

- 原子性：事务中的所有操作要么都会发生，要么都不会。

- Consistency: If each transaction is consistent and the database is consistent at the beginning of the transaction, then the database is guaranteed to be consistent when the transaction completes. “It looks correct to me...”

- 如果每个事务都是一致的，并且数据库在所有事务开始的时候也是一致的，那么当事务完成的时候，数据库保证是一致的。

- Isolation: The execution of one transaction is isolated from that of other transactions. “As if alone”

- 一个事务的执行和其他的事务的执行是隔离的

- Durability: If a transaction commits, then its effects on the database persist. “The transaction’s changes can survive failures...”

- 持久性：如果事务提交，那么它对数据库的影响将是持久的- “也就是说，事务的变更操作可以经受住执行失败的考验”

## ACID: Atomicity  原子性

The DBMS guarantees that transactions are atomic. The transaction either executes all its actions or none of them.

数据库管理系统保证事务是原子的，事务要么执行其所有操作，要么不执行任何操作。

### Approach : Shadow Paging 影子页面

- DBMS makes copies of pages and transactions make changes to those copies. Only when the transaction commits is the page made visible to others.

- DBMS 复制页面，事务对这些副本进行操作。只有当事务提交时，页面才对其他人可见。

### Approach : Logging 日志

- DBMS logs all actions so that it can undo the actions of aborted transactions.

- 数据库管理系统用日志记录所有的操作，以便可以在事务执行异常中止的时候撤销这些事务操作。

- Think of this like the black box in airplanes.

- 可以把它对比成飞机的黑匣子

- Logging is used by all modern systems for audit and efficiency reasons.

- 出于审计和效率的原因，所有的现代数据库系统都使用了日志。

## ACID: Consistency  一致性

The “world” represented by the database is consistent (e.g., correct). All questions (i.e , queries) that the application asks about the data will return correct results.

这个词表示数据库是一致的。应用程序访问的有关数据的所有查询都将返回正确的结果。

### Database Consistency:  数据库一致性

- The database accurately represents the real world entity it is modeling and follows integrity constraints.

数据库准确的表示它正在建模的真实世界实体，并遵循完整性约束。

- Transactions in the future see the effects of transactions committed in the past inside of the database.

将来的事务可以在数据库中看到过去已提交事务的影响。

### Transaction Consistency:  事务一致性

- If the database is consistent before the transaction starts, it will also be consistent after.

如果数据库系统在事务开始之前是一致的，那么在事务执行之后也是一致的。

- Ensuring transaction consistency is the application’s responsibility.

确保事务一致性是应用程序的责任。

## ACID: Isolation

The DBMS provides transactions the illusion that they are running alone in the system. They do not see the effects of concurrent transactions. This is equivalent to a system where transactions are executed in serial order (i.e., one at a time). But in order to get better performance, the DBMS has to interleave the operations of concurrent transactions.

数据库管理系统提供了事务在系统中单独运行的假象。他们看不到并发事务的影响。这等同于事务的执行是以串行的顺序的。但是为了更好的性能，数据库管理系统必须交错并发的执行事务操作。

### Concurrency Control  并发控制

A concurrency control protocol is how the DBMS decides the proper interleaving of operations from multiple transactions.

并发控制协议是指数据库管理系统如何决定来自多个事务的操作以正确的方式交错执行。

There are two categories of concurrency control protocols:

有两大类的并发控制协议:

- Pessimistic: The DBMS assumes that transactions will conflict, so it doesn’t let problems arise in the first place.

- 悲观的：DBMS 假设事务会发生冲突，所以一开始它就不会让问题出现。

- Optimistic: The DBMS assumes that conflicts between transactions are rare, so it chooses to deal
with conflicts when they happen.

- 乐观的：DBMS 假设事务之间的冲突很少，所以它选择在冲突发生的时候再去处理冲突。

The order in which the DBMS executes operations is called an execution schedule. The goal of a concurrency control protocol is to generate an execution schedule that is is equivalent to some serial execution:

DBMS 执行操作的顺序称为执行计划，并发控制协议的目标是生成一个等价于串行执行某些操作的执行计划。


- Serial Schedule: A schedule that does not interleave the actions of different transactions.

串行计划：不交错不同事务操作的计划。

- Equivalent Schedules: For any database state, the effect of execution the first schedule is identical to the effect of executing the second schedule.

等价调度：对于任何数据库状态，执行第一个调度的效果与执行第二个调度的效果相同。

- Serializable Schedule: A schedule that is equivalent to some serial execution of the transactions. When the DBMS interleaves the operations of concurrent transactions, it can create anomalies:

线性化调度：相当于事务的某些串行执行的计划。当DBMS交叉执行并发事务的操作时，它可能会产生异常

- Read-Write Conflicts (“Unrepeatable Reads”): A  
transaction is not able to get the same value when reading the same object multiple times.

读-写冲突（不可重复读取）：事务在多次读取同一个对象时无法获取相同的值。

- Write-Read Conflicts (“Dirty Reads”): A transaction sees the write effects of a different transaction before that transaction committed its changes.

写-读冲突（脏读）：一个事务在提交更改之前会看到另一个事务的写的影响。

- Write-Write conflict (“Lost Updates”): One transaction overwrites the uncommitted data of another concurrent transaction.

写-写冲突（丢失更新操作）：一个事务覆盖另一个并发事务未提交的数据。

There are actually two types for serializability:(1) conflict and (2) view. Neither definition allows all schedules that you would consider serializable. In practice, DBMSs support conflict serializability because it can be enforced efficiently. To allow more concurrency, some special schedules are handled at the application level.

可串行性实际有两种类型：
（1）冲突 （2）视图。

这两种定义都不允许考虑可串行化的所有计划。实际上，DBMS 支持冲突串行化。为了允许更多的并发，在应用程序级别去加一些特殊的调度。

Conflict Serializability  冲突可串行化

Schedules are equivalent to some serial schedule. This is what (almost) every DBMS supports when you
ask for the SERIALIZABLE isolation level.

几乎所有的数据库管理系统都支持 SERIALIZABLE 隔离级别

Schedule S is conflict serializable if you are able to transform S into a serial schedule by swapping consecutive non-conflicting operations of different transactions。

如果可以通过交换不同事务的连续非冲突操作将 S 转换为串行计划，那么 S 是冲突序列化的

Verify using either the swapping method or dependency graphs.

使用交换或者依赖图的方法来验证。

Dependency Graphs (aka “precedence graph”):
依赖关系图（又名“优先图”）

- One node per transaction.

- 每个节点代表一个事务

- Edge from Ti to Tj if an operation Oi of Ti conflicts with an operation Oj of Tj and Oi appears earlier in the schedule than Oj.

- (..)

- A schedule is conflict serializable if and only if its dependency graph is acyclic.

- 当且仅当计划的依赖关系图是非环状的时候，计划是冲突串行化的。

View Serializability  视图可串行化

Allows for all schedules that are conflict serializable and “blind writes”. Thus allows for slightly more schedules than Conflict serializability, but difficult to enforce efficiently. This is because the DBMS does not now how the application will “interpret” values.

## ACID: Durability

All of the changes of committed transactions must be durable (i.e., persistent) after a crash or restart. The DBMS can either use logging or shadow paging to ensure that all changes are durable.

在系统崩溃和重启之后，提交事务的所有更改都必须是持久化的。数据库管理系统可以使用日志记录或者影子页面来确保所有的更改都是持久化的。

