---
title: 动手学习分布式-Multi-分布式事务初探 (Golang eraftkv 版)
date: 2023-08-19 13:35:31
tags:
---

### 事务介绍

在介绍分布式事务之前，我们先来通过一个例子看看事务是什么？

![](/images/demo1.png)

开始讨论我们系统中可能发生的事情之前，我们要重新说一下事务的定义。事务是对数据库的一系列操作，这些操作满足ACID的属性。 我们看到上图的例子，假设我们现在实现的分布式存储系统存储了银行账户数据。 T1表示储蓄用户的账户为Y，他有10块钱，然后他给X转账1块钱，那么对应的数据操作就是对x + 1,对Y - 1 。用户提交这个转账后，系统就开始修改数据库中的值了。 T2表示银行对账人员，她需要统计用户X, Y的账户总和。如果T2在T1开始且还没有操作的时候执行x', y'值得获取，那么能拿到20块的总和，这是符合预期的。 但是，因为两个用户使用系统的时候，他们访问的顺序是随机的，我们无法保证，一旦T2在T1执行add(x, 1)之后读取x', y'的值。我们将得到X + Y = 21，统计莫名的多出了一块钱（似乎银行亏1块钱也没啥问题），如果这笔转账金额很大呢，比如一个小目标1个亿，那就是绝对不能容忍的错误了。 这时候就需要我们的事务保障了。 ACID atomic原子性。数据库管理系统保证事务是原子的，事务要么执行其所有操作，要么不执行任何操作。 cosistent一致性。这个表示数据库是一致的。应用程序访问的有关数据的所有查询都将返回正确的结果。 isolated隔离性。数据库管理系统提供了事务在系统中单独运行的假象。他们看不到并发事务的影响。这等同于事务的执行是以串行的顺序的。但是为了更好的性能，数据库管理系统必须交错并发的执行事务操作。 durable持久性。在系统崩溃和重启之后，提交事务的所有更改都必须是持久化的。数据库管理系统可以使用日志记录或者影子页面来确保所有的更改都是持久化的。 两阶段提交 在一个分布式系统中，数据被分割存储在不同的机器上。例如我们eraft中将数据按哈希值分布到不同的bucket，然后有不同的机器去负责这个bucket数据的存取。这个时候，事务处理就更复杂了。单节点我们可以通过锁保证事务正确性，但是分布式场景就不一样的，我们把上述转账示例带入分布式场景下：

![](/images/2pc.png)

### 两阶段提交

账户数据存储在S1, S2两台不同的机器上。T1在S1上执行+1操作，X现在等于11。当T1执行到对Y减1操作的时候，服务S2奔溃掉了。那么这时候这个操作返回用户失败，但是S1上的账户已经脏了，这时候对账人员去对账也会得到错误的数据。 面对这种场景分布式系统是如何去解决的呢？ 这个时候就需要一个节点作为事务协调者 Transaction Coordinator，来协调事务的执行了，S1，S2负责执行事务，他们被称为事务参与者 Participants。 我们首先概览以下两阶段提交是如何工作的

![](/images/2pc_flow.png)

首先在我们的图中，假定TC, S1, S2都位于不同的服务器。TC是事务执行的协调者。S1, S2是持有数据的服务节点。 事务协调器TC会给S1发消息告诉它要对X进行+1操作，给服务器S2发消息告诉它对Y进行-1操作。后面会有一系列的消息来确认，要么S1, S2都成功执行了相应的，要么两个服务器都没有执行操作，不会出现非原子操作的状态，这就是两阶段提交的大致流程。

#### 捐赠

整理这本书耗费了我们大量的时间和精力。如果你觉得有帮助，一瓶矿泉水的价格支持我们继续输出优质的分布式存储知识体系，2.99¥，感谢大家的支持。

![](/images/alipay.jpeg)

[下载 PDF 版本](https://github.com/eraft-io/eraft-io.github.io/blob/eraft_home/docs/resources/eraft_book.pdf)


<script src="https://giscus.app/client.js"
    data-repo="eraft-io/eraft-io.github.io"
    data-repo-id="MDEwOlJlcG9zaXRvcnkzOTYyMDM3NjU="
    data-category="General"
    data-category-id="DIC_kwDOF52W9c4CRblA"
    data-mapping="pathname"
    data-strict="0"
    data-reactions-enabled="1"
    data-emit-metadata="0"
    data-input-position="bottom"
    data-theme="preferred_color_scheme"
    data-lang="zh-CN"
    crossorigin="anonymous"
    async>
</script>

<script async src="//busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js"></script>
<span id="busuanzi_container_site_pv">本站总访问量<span id="busuanzi_value_site_pv"></span>次</span>
