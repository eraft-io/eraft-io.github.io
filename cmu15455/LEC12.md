# Query Processing I 查询过程I

## 1. Query Plan 查询计划

The DBMS converts a SQL statement into a query plan. Operators are arranged in a tree. Data flows from the leaves towards the root. The output of the root node in the tree is the result of the query. Typically operators are binary (1–2 children). The same query plan can be executed in multiple ways. Most DBMSs will want to use an index scan as much as possible.

DBMS将SQL语句转换为查询计划。运算符排列在树中。数据从叶子流向根。树中根节点的输出是查询的结果。通常运算符是二进制的（1-2 个子项）。可以通过多种方式执行相同的查询计划。大多数DBMS都希望尽可能多地使用索引扫描。

## 2. Processing Models 处理模型
A DBMS processing model defines how the system executes a query plan. There are different models that have various trade-offs for different workloads.

DBMS处理模型定义系统如何执行查询计划。对于不同的工作负载，具有不同权衡的各种模型。

These models can also be implemented to invoke the operators either from top-to-bottom (most common) or from bottom-to-top.

还可以实现这些模型，以便从上到下（最常见）或从下到上调用运算符。

### Iterator Model 迭代器模型
This is the most common processing model and is used by almost every (row-based) DBMS. Allows for pipelining where the DBMS can process a tuple through as many operators as possible before having to retrieve the next tuple.

这是最常见的处理模型，几乎每个（基于行的）DBMS 都使用。允许流水线，其中DBMS可以在必须检索下一个元组之前通过尽可能多的运算符处理元组。

Every query plan operator implements a next function:
* On each call to next, the operator returns either a single tuple or a null marker if there are no more tuples.
* The operator implements a loop that calls next on its children to retrieve their tuples and then process them (i.e., calling next on a parent calls next on their children).

每个查询计划运算符都实现next函数：
* 在每次调用next时，如果没有更多的元组，则运算符返回单个元组或空标记。
* 运算符实现一个循环，该循环在其子级上调用 next 以检索其元组，然后处理它们（即，在子级调用的父级调用next时调用next）。

Some operators will block until children emit all of their tuples (joins, subqueries, order by). These are known as pipeline breakers.

某些运算符将阻塞，直到子级发出其所有元组（连接、子查询、排序依据）。这些被称为管道断路器。


Output control works easily with this approach (LIMIT) because an operator can stop invoking next on its children operators once it has all the tuples that it requires.

输出控制使用LIMIT方法很容易，因为一旦操作员拥有所需的所有元组，就可以停止在其子运算符上调用 next。



### Materialization Model 物化模型
Each operator processes its input all at once and then emits its output all at once. The operator “materializes” its output as a single result.

每个操作员一次处理其所有输入，然后一次发出所有输出。运营商“具体化”其输出为单个结果。

Every query plan operator implements an output function:
• The operator processes all the tuples from its children at once.
• The return result of this function is all the tuples that operator will ever emit. When the operator finishes executing, the DBMS never needs to return to it to retrieve more data.


每个查询计划运算符都实现一个输出函数：
• 操作员一次处理其子级中的所有元组。
• 此函数的返回结果是运算符将发出的所有元组。当操作员完成执行时，DBMS永远不需要返回到它来检索更多数据。

This approach is better for OLTP workloads because queries typically only access a small number of tuples at a time. Thus, there are fewer function calls to retrieve tuples. Not good for OLAP queries with large intermediate results because the DBMS may have to spill those results to disk between operators.

此方法更适合OLTP工作负荷，因为查询通常一次只能访问少量元组。因此，用于检索元组的函数调用较少。这不利于具有较大中间结果的OLAP查询，因为DBMS可能必须在运算符之间将这些结果溢出到磁盘。


### Vectorization Model 矢量化模型
Like the iterator model where each operator implements a next function. But each operator emits a batch (i.e., vector) of data instead of a single tuple:
* The operator implementation can be optimized for processing batches of data instead of a single item at a time.
This approach is ideal for OLAP queries that have to scan a large number of tuples because there are fewer invocations of the next function.

就像迭代器模型一样，每个运算符实现下一个函数。但是每个运算符发出一批（即向量）数据，而不是单个元组：
* 操作员实现可以针对处理批量数据进行优化，而不是一次处理单个项目。
此方法非常适合必须扫描大量元组的OLAP查询，因为对下一个函数的调用较少。

## Access Methods 访问方法
An access method is the how the DBMS accesses the data stored in a table. These will be the bottom operators in a query plan that “feed” data into the operators above it in the tree. There is no corresponding operator in relational algebra.

访问方法是DBMS访问存储在表中的数据的方式。这些将是查询计划中的底部运算符，它们将数据“馈送到”树中其上方的运算符中。关系代数中没有相应的运算符。

### Sequential Scan 序列扫描
For each page in table, iterate over each page and retrieve it from the buffer pool. For each page, iterate over all the tuples and evaluate the predicate to decide whether to include tuple or not.

对于表中的每个页面，循环访问每个页面并从缓冲池中检索它。对于每个页面，循环访问所有元组并计算谓词以决定是否包含元组。

Optimizations:
* Prefetching: Fetches next few pages in advance so that the DBMS does not have to block when accessing each page.
* Parallelization: Execute the scan using multiple threads/processes in parallel. 
* Buffer Pool Bypass: The scan operator stores pages that it fetches from disk in its local memory instead of the buffer pool. This avoids the sequential flooding problem.
* Zone Map: Pre-compute aggregations for each tuple attribute in a page. The DBMS can then check whether it needs to access a page by checking its Zone Map first. The Zone Maps for each page are stored in separate pages and there are typically multiple entries in each Zone Map page. Thus, it is possible to reduce the total number of pages examined in a sequential scan.
* Late Materialization: Each operator passes the minimal amount of information needed to by the next operator (e.g., record id). This is only useful in column-store systems (i.e., DSM).
* Heap Clustering: Tuples are stored in the heap pages using an order specified by a clustering index.

优化：
* 预抓取：提前抓取接下来的几页，这样DBMS在访问每个页面时就不必被阻塞了。
* 并行化：使用多个线程/进程并行执行扫描。
* 缓冲池绕过：扫描运算符将从磁盘获取的页面存储在其本地内存（而不是缓冲池）中。这避免了顺序泛洪问题。
* 区域映射：为页面中的每个元组属性预先计算聚合。然后，DBMS 可以通过先检查其区域映射来检查是否需要访问页面。每个页面的区域地图都存储在单独的页面中，并且每个区域地图页面中通常有多个条目。因此，可以减少顺序扫描中检查的总页数。
* 晚物化：每个操作员传递下一个操作员所需的最少信息量（例如，记录 ID）。这仅在列存储系统（即DSM）中有用。
* 堆聚类：元组使用聚类索引指定的顺序存储在堆页中。



### Index Scan 索引扫描
The DBMS picks an index (or indexes) to find the tuples that the query needs.

DBMS 选取一个（或多个索引）以查找查询所需的元组。

When using multiple indexes, the DBMS executes the search on each index and generates the set of matching record ids. One can implement this record id using bitmaps, hash tables, or Bloom filters. The DBMS combines these sets based on the query’s predicates (union vs. intersect). It then retrieve the records and apply any remaining terms. The more advanced DBMSs support multi-index scans.

使用多个索引时，DBMS 将对每个索引执行搜索并生成一组匹配的recordID。可以使Bitmap、哈希表或Bloom滤波器实现此recordID。DBMS根据查询的谓词（并集与相交）组合这些集。然后，它检索记录并应用任何剩余的术语。更高级的DBMS支持多索引扫描。

Retrieving tuples in the order that they appear in an unclustered index is inefficient. The DBMS can first figure out all the tuples that it needs and then sort them based on their page id.

按元组在非聚集索引中出现的顺序检索元组是低效的。DBMS可以首先找出它需要的所有元组，然后根据其pageID对它们进行排序。

## Expression Evaluation 表达式计算
The DBMS represents a query plan as a tree. Inside of the operators will be an expression tree. For example, the WHERE clause for a filter operator.
The nodes in the tree represent different expression types:
* Comparisons (=, <, >, !=) 
* Conjunction (AND), Disjunction (OR) 
* Arithmetic Operators (+, -, *, /, %) 
* Constant and Parameter Values
* Tuple Attribute References
To evaluate an expression tree at runtime, the DBMS maintains a context handle that contains metadata for the execution, such as the current tuple, the parameters, and the table schema. The DBMS then walks the tree to evaluate its operators and produce a result.


DBMS将查询计划表示为树。运算符内部将是一个表达式树。例如，筛选器运算符的 WHERE 子句。
树中的节点表示不同的表达式类型：
* 比较 （=， <， >， ！=） 
* 连词 （AND）， 析取 （OR）
* 算术运算符 （+， -， *， /， %） 
* 常量和参数值
* 元组属性引用
为了在运行时计算表达式树，DBMS 维护一个上下文句柄，其中包含执行的元数据，例如当前元组、参数和表架构。然后，DBMS遍历树以评估其运算符并生成结果。
