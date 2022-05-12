# 第七讲

### topic: the Raft log (Lab 2B)
raft 日志

as long as the leader stays up:

只要 leader 不暂停

clients only interact with the leader

客户端只与 leader 交互

clients don't see follower states or logs

客户端并看不到 follower 的状态或者日志

things get interesting when changing leaders

当 leader 变更的时候，事情变得有趣了

e.g. after the old leader fails

例如: 老的 leader 故障了

how to change leaders without anomalies?

如何保证切换 leader 之后不出现异常

diverging replicas, missing operations, repeated operations

分散的副本，丢失的操作，重复操作

### what do we want to ensure?

我们想要确保什么？

if any server executes a given command in a log entry,

如果任何服务器执行日志条目中一个给定的命令

then no server executes something else for that log entry

没有服务器为那个日志执行其他的操作

why? if the servers disagree on the operations, then a
change of leader might change the client-visible state,
which violates our goal of mimicing a single server.

为什么？如果服务节点在操作上存在分歧，那么 leader 的变更可能会改变
客户端的可见状态，这违背了我们要模拟单个服务器的目标

example:

S1: put(k1,1) | put(k1,2) 

S2: put(k1,1) | put(k2,3) 

can't allow both to execute their 2nd log entries!

绝对不能让他们同时执行第二条日志里面的操作

### how can logs disagree?

a leader crashes before sending AppendEntries to all

假设 S3 是 LEADER, 这里 S1 没有复制到数据

S1: 3
S2: 3 3
S3: 3 3

(the 3s are the term number in the log entry)

3 是日志条目的任期号

worse: logs might have different commands in same entry!

更糟糕的是，在同一个日志条目中可能有不同的命令

after a series of leader crashes, e.g.

    10 11 12 13  <- log entry #
S1:  3
S2:  3  3  4
S3:  3  3  5

Raft forces agreement by having followers adopt new leader's log

  example:

  S3 is chosen as new leader for term 6

  S3 wants to append a new log entry at index 13

  S3 sends an AppendEntries RPC to all
  
     prevLogIndex=12
     prevLogTerm=5

  S2 replies false (AppendEntries step 2)

  S3 decrements nextIndex[S2] to 12

  S3 sends AppendEntries w/ entries 12+13, prevLogIndex=11, prevLogTerm=3

  S2 deletes its entry 12 (AppendEntries step 3)

    and appends new entries 12+13

  similar story for S1, but S3 has to back up one farther
