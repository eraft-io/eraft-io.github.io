# Lecture 8 树索引 II

## Additional Index Usage 附加索引的使用

1. Implicit Indexes: Most DBMSs will automatically create an index to enforce integrity constraints (e.g., primary keys, unique constraints).

隐式索引：大多数 DBMS 会自动创建一个索引来强制实施完整性约束（例如，主键、唯一约束）。

代码案例：CREATE UNIQUE INDEX 索引名 ON 表名(字段名);
   
2. Partial Indexes: Create an index on a subset of the entire table. This potentially reduces size and the amount of overhead to maintain it.

局部索引：在整个表的子集上创建索引。这可能会减小大小和维护它的开销量。

代码案例：CREATE INDEX 索引名 ON 表名(字段名) WHERE 子集筛选条件;
   
3. Convering Indexes: All attributes needed to process the query are available in an index, then the DBMS does not need to retrieve the tuple. The DBMS can complete the entire query just based on the data available in the index.

覆盖索引：查询所需的所有字段都已包含在索引中，DBMS 可以根据索引中的可用数据完成整个查询，不需要通过回表操作检索数据元组(在组合索引中出现)。

代码案例：CREATE INDEX 索引名 ON 表名(字段1，字段2); SELECT 字段2 FROM 表名 WHERE 筛选字段1;
   

4. Index Include Columns: Embed additional columns in index to support index-only queries.

包含索引：在索引中嵌入其他列以支持仅索引查询（防止回表操作）。

代码案例：CREATE INDEX 索引名 ON 表名(字段1，字段2) INCLUDE (字段3); SELECT 字段2 FROM 表名 WHERE 筛选字段1 AND 筛选字段2;
   
5. Function/Expression Indexes: Store the output of a function or expression as the key instead of the original value. It is the DBMS’s job to recognize which queries can use that index.

函数索引：将函数或表达式的输出存储为键，而不是原始值。DBMS的工作是识别哪些查询可以使用该索引。
代码案例：若要查询SELECT * FROM user WHERE EXTRACT(dow from login) =2; 可通过以下方式构建函数索引：

        方式一：CREATE INDEX 索引名 ON user(EXTRACT(dow from login)); 
        
        方式二：CREATE INDEX 索引名 ON user(login) WHERE EXTRACT(dow from login)=2;


## Radix Tree 基数树
A radix tree is a variant of a trie data structure. It uses digital representation of keys to examine prefixes one-by-one instead of comparing entire key. It is different than a trie in that there is not a node for each element in key, nodes are consolidated to represent the largest prefix before keys differ.

基数树是trie数据结构的变体（在树的横向和纵向结构上都进行了优化）。它是逐个比较构成键的数字的前缀元素，而不是比较整个键。它与trie的不同之处在于，键中的每个元素并不一定都占有一个节点，可以表示键不同之前的最大前缀会进行合并。


The height of tree depends on the length of keys and not the number of keys like in a B+Tree. The path to a leaf nodes represents the key of the leaf. Not all attribute types can be decomposed into binary comparable digits for a radix tree.

树的高度取决于键的长度，而不是像B+树是取决于键的数量，并且叶节点的路径可以表示键值。但是并非所有属性类型都可以分解为基数树中的二进制可比数字。


## Inverted Indexes 倒排索引
An inverted index stores a mapping of words to records that contain those words in the target attribute. These are sometimes called a full-text search indexes in DBMSs.

倒排索引存储单词到目标属性中包含这些单词的记录的映射。这些索引有时称为 DBMS 中的全文搜索索引。

Most of the major DBMSs support inverted indexes natively, but there are specialized DBMSs where this is the only table index data structure available.

大多数主要的DBMS本身都支持倒排索引，但也有专门的DBMS，并且是其中唯一可用的表索引数据结构。

Query Types:

1. Phrase Searches: Find records that contain a list of words in the given order.
2. Proximity Searches: Find records where two words occur within n words of each other.
3. WildcardSearches:Findrecordsthatcontainwordsthatmatchsomepattern(e.g.,regularexpression).

查询类型：

1. 短语搜索：按给定顺序查找字包含词列表的记录。
2. 邻近搜索：查找两个单词出现在n个单词内的记录。
3. 通配符搜索：查找包含与某些模式匹配的单词（例如，正则表达式）的记录。


Design Decisions: 
1. What To Store: The index needs to store at least the words contained in each record (separated by punctuation characters). It can also include additional information such as the word frequency, position, and other meta-data.
2. When To Update: Updating an inverted index every time the table is modified is expensive and slow. Thus, most DBMSs will maintain auxiliary data structures to “stage” updates and then update the index in batches.


决策设计：
1. 要存储的内容：索引至少需要存储每条记录中包含的单词（用标点符号分隔）。它还可以包括其他信息，例如词频，位置和其他元数据。
2. 何时更新：每次修改表时更新倒排索引既昂贵又缓慢。因此，大多数DBMS将维护辅助数据结构以"暂存"更新，然后批量更新索引。


## 总结

本章中提到的附加索引和Radix树索引都可以支持单点查询和范围查询，而倒排索引(一种单词-文档形式的矩阵数据结构)则是一种支持全文索引的数据结构，更适合用于模糊查询的场景。

