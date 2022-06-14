# Lecture 18: Timestamp Ordering  时间戳排序

## Timestamp Ordering Concurrency Control  基于时间戳排序的并发控制协议

Timestamp ordering (T/O) is a optimistic class of concurrency control protocols where the DBMS assumes that transaction conflicts are rare. Instead of requiring transactions to acquire locks before they are allowed to read/write to a database object, the DBMS instead uses timestamps to determine the serializability order of transactions.

时间戳排序（T/O）是一种乐观类的并发控制协议，其中DBMS假设


