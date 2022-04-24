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

