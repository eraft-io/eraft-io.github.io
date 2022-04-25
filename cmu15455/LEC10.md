# Lecture 10 Sorting & Aggregation Altorithms 排序 & 聚集算法
## Sorting 排序
We need sorting because in the relation model, tuples in a table have no specific order Sorting is (potentially) used in ORDER BY, GROUP BY, JOIN, and DISTINCT operators.

我们需要排序，因为在关系模型中，表中的元组没有特定的顺序排序（可能）用于 ORDER BY、GROUP BY、JOIN 和 DISTINCT运算符。

We can accelerate sorting using a clustered B+tree by scanning the leaf nodes from left to right. This is a bad idea, however, if we use an unclustered B+tree to sort because it causes a lot of I/O reads (random access through pointer chasing).

我们可以通过从左到右扫描聚集B+树叶节点来加速排序。但是，如果我们使用未聚集的B+树进行排序，这是一个坏主意，因为它会导致大量的 I/O 读取（通过指针追逐进行随机访问）。


If the data that we need to sort fits in memory, then the DBMS can use a standard sorting algorithms (e.g., quicksort). If the data does not fit, then the DBMS needs to use external sorting that is able to spill to disk as needed and prefers sequential over random I/O.

如果我们需要排序的数据适合内存，则DBMS可以使用标准的排序算法（例如，快速排序）。如果数据不合适，则 DBMS 需要使用能够根据需要溢出到磁盘的外部排序，并且优先选择顺序而不是随机I/O。、

## External Merge Sort 外部合并排序
Divide-and-conquer sorting algorithm that splits the data set into separate runs and then sorts them individually. It can spill runs to disk as needed then read them back in one at a time.

分而治之排序算法，该算法将数据集拆分为单独的运行，然后对它们进行单独排序。它可以根据需要将运行溢出到磁盘，然后一次读取一个。

Phase #1 – Sorting: Sort small chunks of data that fit in main memory, and then write back to disk.
Phase #2 – Merge: Combine sorted sub-files into a larger single file.

阶段#1 - 排序：对适合主内存的小块数据进行排序，然后写回磁盘。
阶段#2 - 合并：将排序的子文件合并为一个更大的单个文件。

### Two-way Merge Sort 双向合并排序
1. Pass #0: Reads every B pages of the table into memory. Sorts them, and writes them back into disk. Each sorted set of pages is called a run.
2. Pass #1,2,3...: Recursively merges pairs of runs into runs twice as long. 
Number of Passes: 1 + log_2^N
Total I/O Cost: 2N × (# of passes)

1. 传递 #0：将表的每B页读取到内存中。对它们进行排序，并将它们写回磁盘。每组经过排序的页面称为一次运行。
2. 传递 #1，2，3...：递归地将运行对合并为两倍的运行。
通过次数： 1 +「lg_2^N」
总I/O成本：2N ×（通过次数）


### General (K-way) Merge Sort 常规（K-way）合并排序
1. Pass #0: Use B buffer pages, produce N/B sorted runs of size B.
2. Pass #1,2,3...: Recursively merge B B 1 runs.
Number of Passes = 1 + 「log_{B-1}^ 「N/B」」
Total I/O Cost: 2N × (# of passes)

1. 通过 #0：使用 B 缓冲区页面，生成大小为B的N/B排序运行。
2. 传递 #1，2，3...：递归合并B-1次
通过次数 = 1 + 「log_{B-1}^ 「N/B」」
总I/O成本：2N ×（通过次数）

### Double Buffering Optimization 双缓冲优化
Prefetch the next run in the background and store it in a second buffer while the system is processing the current run. This reduces the wait time for I/O requests at each step by continuously utilizing the disk.

在后台预取下一次运行，并在系统处理数据时将其存储在第二个缓冲区中当前运行。这通过持续利用磁盘减少了每一步I/O请求的等待时间。

## Aggregations 聚集
An aggregation operator in a query plan collapses the values of one or more tuples into a single scalar value. There are two approaches for implementing an aggregation: (1) sorting and (2) hashing.

查询计划中的聚合运算符将一个或多个元组的值折叠为单个标量值。有两种实现聚合的方法：（1） 排序和 （2） 哈希。

### Sorting 排序
The DBMS first sorts the tuples on the GROUP BY key(s). It can use either an in-memory sorting algorithm if everything fits in the buffer pool (e.g., quicksort) or the external merge sort algorithm if the size of the data exceeds memory.

DBMS 首先对 GROUP BY 键上的元组进行排序。如果所有内容都适合缓冲池（例如，快速排序），则可以使用内存中排序算法，如果数据大小超过内存，则可以使用外部合并排序算法。

The DBMS then performs a sequential scan over the sorted data to compute the aggregation. The output of the operator will be sorted on the keys

然后，DBMS 对排序的数据执行顺序扫描以计算聚合。运算符的输出将按键排序

## Hashing 哈希
Hashing can be computationally cheaper than sorting for computing aggregations. The DBMS populates an ephemeral hash table as it scans the table. For each record, check whether there is already an entry in the hash table and perform the appropriate modification.

散列在计算上可能比计算聚合的排序更便宜。DBMS 在扫描临时哈希表时填充该表。对于每条记录，请检查对哈希表执行适当的修改。

If the size of the hash table is too large to fit in memory, then the DBMS has to spill it to disk:
* Phase #1 – Partition: Use a hash function h1 to split tuples into partitions on disk based on target hash key. This will put all tuples that match into the same partition. The DBMS spills partitions to disk via output buffers.
* Phase #2 – ReHash: For each partition on disk, read its pages into memory and build an in-memory hash table based on a second hash function h2 (where h1  not equal to h2). Then go through each bucket of this hash table to bring together matching tuples to compute the aggregation. Note that this assumes that each partition fits in memory

如果哈希表的大小太大而无法放入内存，则DBMS必须将其溢出到磁盘：
* 阶段 #1 – 分区：使用哈希函数 h1 根据目标哈希键将元组拆分为磁盘上的分区。这会将所有匹配的元组放入同一分区中。DBMS 通过输出缓冲区将分区溢出到磁盘。
* 阶段 #2 – 重新哈希：对于磁盘上的每个分区，将其页面读入内存，并根据第二个哈希函数 h2（其中 h1不等于h2）构建内存中哈希表。然后遍历此哈希表的每个存储桶，以将匹配的元组组合在一起以计算聚合。请注意，这假设每个分区都适合内存。


During the ReHash phase, the DBMS can store pairs of the form (GroupByKey→RunningValue) to compute the aggregation. The contents of RunningValue depends on the aggregation function. To insert a new tuple into the hash table:
* If it finds a matching GroupByKey, then update the RunningValue appropriately.
* Else insert a new (GroupByKey→RunningValue) pair.

在重哈希阶段，DBMS 可以存储表单（GroupByKey→RunningValue）的对来计算聚合。运行值的内容取决于聚合函数。将新元组插入到哈希表中：
* 如果找到匹配的 GroupByKey，请相应地更新运行值。
* 否则，插入一个新的（GroupByKey→RunningValue）对。
