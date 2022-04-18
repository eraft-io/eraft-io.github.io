# Lecture 15: Query Planning & Optimization II  查询计划 & 优化

### 1 Cost-based Query Optimization  基于成本的查询优化

The DBMS’s optimizer will use an internal cost model to estimate the execution cost for a particular query plan. This provides an estimate to determine whether one plan is better than another without having to actually run the query (which would be slow to do for thousands of plans).

DBMS 的优化器将使用一个内部的代价模型来估计特定查询计划执行的成本。这提供了一个预估值，用来确定一个计划是否优于另一个计划，这并不需要我们去实际运行查询来确定（对于拥有数千个查询计划的查询来说，这样做显然会很慢）。

This estimate is an internal metric that
(usually) is not comparable to real-world metrics, but it can be derived from estimating the usage of different resources:

这种预估是一种内部的指标，通常与现实世界的指标无法比较，但是它可以通过估计不同资源的使用情况得出来：

• CPU: Small cost; tough to estimate.

CPU：开销低，很难去估计。

• Disk: Number of block transferred.

磁盘：传输的数据块数

• Memory: Amount of DRAM used.

内存：使用 DRAM 的量

• Network: Number of messages transfered.

网络：传输的消息数

To accomplish this, the DBMS stores internal statistics about tables, attributes, and indexes in its internal catalog. Different systems update the statistics at different times. Commercial DBMS have way more robust and accurate statistics compared to the open source systems. These are estimates and thus the cost estimates will often be inaccurate.

为了实现这一点，DBMS 在其内部目录中存储关于表、属性和索引的内部统计信息。不同的系统在更新这些统计信息的时间不同。商业数据库管理系统具有更强大、更准确的统计数据。这些信息都是估算，它们往往不一定能做的特别准确。

### 2 Statistics  统计数字

For a relation R, the DBMS stores the number of tuples (NR) and distinct values per attribute (V (A, R)).

对于关系 R，DBMS存储每个属性的元组数 (NR) 和不同值的数量 (V (A, R))，

The selection cardinality (SC(A, R)) is the average number of records with a value for an attribute A given NR/V (A, R).

选择基数 (SC(A, R)) 是具有给定 NR/V(A, R) 属性值的记录数的平均数。

Complex Predicates 复杂谓词

• The selectivity (sel) of a predicate P is the fraction of tuples that qualify:

```
sel(A = constant) = SC(P)/V (A, R)
```

• For a range query, we can use: sel(A >= a) = (Amax − a/(Amax − Amin)).

• For negations: sel(notP) = 1 − sel(P).

• The selectivity is the probability that a tuple will satisfy the predicate. Thus, assuming predicates are independent, then sel(P1 ^ P2) = sel(P1) ∗ sel(P2).

Join Estimation

• Given a join of R and S, the estimated size of a join on non-key attribute A is approx

estSize ≈ NR ∗ NS/max(V (A, R), V (A, S))

Statistics Storage: 统计数据存储

Histograms: We assumed values were uniformly distributed. But in real databases values are not uniformly distributed, and thus maintaining a histogram is expensive. We can put values into buckets to reduce the size of the histograms. However, this can lead to inaccuracies as frequent values will sway the count of infrequent values. To counteract this, we can size the buckets such that their spread is the same. They each hold a similar amount of values.

直方图：我们假设值是均匀分布的。但是在真实的数据库中，值并不是均匀分布的，因此维护直方图的开销是昂贵的。我们可以将值放入桶中来见减小直方图的大小。然而，这可能会导致不精确，因为那些频繁访问的值会影响不频繁访问值的计数。为了抵消这一点，我们可以调整桶的大小，使得其排列相同。它们各自持有相同数量的值。
