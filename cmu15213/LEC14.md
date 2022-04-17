# Lecture 14: 查询计划 & 优化 I

## Overview

SQL is declarative. This means that the user tells the DBMS what answer they want, not how to get the answer. Thus, the DBMS needs to translate a SQL statement into an executable query plan. But there are different ways to execute a query (e.g., join algorithms) and there will be differences in performance for these plans. Thus, the DBMS needs a way to pick the “best” plan for a given query. This is the job of the DBMS’s optimizer.

SQL 是陈述性的语言。这意味着用户告诉数据库管理系统他们想要什么答案，而不是如何得到答案。因此，数据库管理系统的需要将 SQL 语句转换成可以执行的查询计划。但是执行的方式不同（例如，连接算法），这些计划的性能也会有所不同。因此，数据库管理系统需要有办法找出一个给定查询的最佳查询计划。这就是数据库管理系统查询优化器的工作。

There are two types of optimization strategies:

有两种类型的优化策略:

• Heuristics/Rules: Rewrite the query to remove inefficiencies. Does not require a cost model.

启发式/规则：重写查询以消除低效，这种方式不需要一个成本模型。

• Cost-based Search: Use a cost model to evaluate multiple equivalent plans and pick the one with the smallest cost.

基于成本的搜索：使用一个成本模型去评估多个等效的查询计划，并选择出最小的计划。

## Rule-based Query Optimization  基于规则的查询优化

Two relational algebra expressions are equivalent if they generate the same set of tuples. Given this, the DBMS can identify better query plans without a cost model. This is technique often called query rewriting. Note that most DBMSs will rewrite the query plan and not the raw SQL string.

如果两个关系代数表达式计算生成相同的元组集合，则它们是等价的。鉴于此，数据库管理系统可以在没有成本模型的情况下确定更好的查询计划。这种技术通常被称为查询重写，注意大多数数据库管理系统都会重写查询计划，而不是原始的 SQL 字符串。

Examples of query rewriting:

查询重写的例子:

• Predicate Push-down: Perform predicate filtering before join to reduce size of join.

谓词下推：在连接之前先执行谓词过滤，以减少连接所操作数据量的大小。

• Projections Push down: Perform projections early to create smaller tuples and reduce intermediate results. You can project out all attributes except the ones requested or required (e.g. join attributes).

投影下推：尽早的执行投影以创建较小的元组信息减少中间结果。除了请求必须的属性之外，你可以投射出所有的属性。

• Expression Simplification: Exploit the transitive properties of boolean logic to rewrite predicate expressions into a more simple form.

表达式简化：利用布尔逻辑的传递特性将谓词表达式重写为更简单的形式。
