## 上手体验基于 Raft 算法实现的分布式 KV 服务。

### 源码介绍
ETCD 项目源码提供了一个基于 raft 库，构建一个 REST API 风格的分布式 KV 存储集群。它的源码在 https://github.com/etcd-io/etcd/tree/main/contrib/raftexample。

这个 raftexample 由三部分组成：

- 由 raft 支持实现的 **kvstore**

kvstore 维护了一个 kv map 保存了所有已经提交到系统的 kv，它的作用是打通 REST API 服务和 raft 服务之间的通信。kv 的更新操作通过 kvstore 发布到 raft 共识服务，当 raft 共识服务 通知 kv 已经完成提交操作时，kvstore 会更新自己的 kv map。

- 一个 REST 风格的 **API**

REST API 服务相当于将当前的共识服务暴露给客户端，客户端通过发送 HTTP 协议的 GET 请求可以分布式存储系统中获取 kv 对，同时也可以通过 HTTP 协议的 PUT 操作提交 kv 对的更新操作到系统中。

- 基于 etcd raft 库提供的 **raft 共识服务**

raft 共识服务维护参与集群的多个节点的共识，当 REST API 提交 kv 到系统之后，kvstore 会将 kv 转换成一个提案，提交到 raft 共识服务。当集群到达共识状态后，提交的提案会发送到 commit channel，kvstore 会消费这个 channel 的消息，将已经提交的 kv 数据写入到自己的 kv map 中。

### 打包构建

- 本书实验环境版本信息

| 软件环境 | 版本 | 安装文档 
| ---:|:---:| :--- |
| Linux OS | 5.10.134-18.al8.x86_64 | https://ecs-buy.aliyun.com/ecs
| Golang | go1.24.4.linux-amd64 | https://go.dev/doc/install 
| etcd raft example | v3.6.1 |  https://github.com/etcd-io/etcd/tree/main/contrib/raftexample

Linux 系统你可以直接在云服务商购买按量付费的 ecs 做实验，系统可以选择默认的 Alibaba Cloud Linux。Golang 环境的安装在官网有详细的步骤，你可以选择对应的 bin 文件下载解压到系统目录，并设置 PATH 环境变量。
Golang 环境准备好之后，可以执行
```
go build -o raftexample
```
生成 raftexample 的可执行文件。

### 运行 ETCD raft example 分布式 KV 服务

#### 运行单节点模式的 raft example

```
raftexample --id 1 --cluster http://127.0.0.1:12379 --port 12380
```
上面的命令启动了一单节点模式运行的 raft 集群

--id 指定了 raft 节点的 id，--cluster 指定了 raft 节点地址列表，12379 用来作为 raft 节点间做内部通信端口。 --port 是提供 REST API KV API 的 http 服务端口。

运行以上命令后，进程启动输出如下：

```
./raftexample --id 1 --cluster http://127.0.0.1:12379 --port 12380
2025/07/01 22:25:58 replaying WAL of member 1
2025/07/01 22:25:58 loading WAL at term 0 and index 0
raft2025/07/01 22:25:58 INFO: 1 switched to configuration voters=()
raft2025/07/01 22:25:58 INFO: 1 became follower at term 0
raft2025/07/01 22:25:58 INFO: newRaft 1 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
raft2025/07/01 22:25:58 INFO: 1 became follower at term 1
raft2025/07/01 22:25:58 INFO: 1 switched to configuration voters=(1)
raft2025/07/01 22:25:58 INFO: 1 switched to configuration voters=(1)
raft2025/07/01 22:25:59 INFO: 1 is starting a new election at term 1
raft2025/07/01 22:25:59 INFO: 1 became candidate at term 2
raft2025/07/01 22:25:59 INFO: 1 received MsgVoteResp from 1 at term 2
raft2025/07/01 22:25:59 INFO: 1 has received 1 MsgVoteResp votes and 0 vote rejections
raft2025/07/01 22:25:59 INFO: 1 became leader at term 2
raft2025/07/01 22:25:59 INFO: raft.node: 1 elected leader 1 at term 2
```

输出的日志可以暂时不用理解，后续在我们讲到 raft 短发细节的时候我们会再做详细介绍，在这个例子中你只需要知道我们启动了一个监听端口为 12380 的 REST API KV API 单节点分布式服务。

你可以运行下面的命令对系统进行写入测试：
```
curl -L http://127.0.0.1:12380/my-key -XPUT -d hello
```
要验证读取操作，可以通过下述命令：
```
curl -L http://127.0.0.1:12380/my-key
```

#### 运行集群模式的 raft example
可以看到 raftexample 源码目录下有一个 Procfile 文件
```
# Use goreman to run `go install github.com/mattn/goreman@latest`
raftexample1: ./raftexample --id 1 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 12380
raftexample2: ./raftexample --id 2 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 22380
raftexample3: ./raftexample --id 3 --cluster http://127.0.0.1:12379,http://127.0.0.1:22379,http://127.0.0.1:32379 --port 32380
```

这里面指定了集群中每一个节点的启动命令，要运行这个集群，我们需要安装 goreman。

```
go install github.com/mattn/goreman@latest
```
运行后，可以看到集群的多个节点依次启动了

```
goreman start
07:50:28 raftexample1 | Starting raftexample1 on port 5000
07:50:28 raftexample2 | Starting raftexample2 on port 5100
07:50:28 raftexample3 | Starting raftexample3 on port 5200
07:50:28 raftexample3 | 2025/07/02 07:50:28 replaying WAL of member 3
07:50:28 raftexample1 | 2025/07/02 07:50:28 replaying WAL of member 1
07:50:28 raftexample2 | 2025/07/02 07:50:28 replaying WAL of member 2
07:50:28 raftexample1 | 2025/07/02 07:50:28 loading WAL at term 0 and index 0
07:50:28 raftexample3 | 2025/07/02 07:50:28 loading WAL at term 0 and index 0
07:50:28 raftexample2 | 2025/07/02 07:50:28 loading WAL at term 0 and index 0
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 switched to configuration voters=()
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 switched to configuration voters=()
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 switched to configuration voters=()
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 became follower at term 0
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: newRaft 1 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 became follower at term 0
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: newRaft 3 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 became follower at term 1
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 switched to configuration voters=(1)
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 switched to configuration voters=(1 2)
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 switched to configuration voters=(1 2 3)
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 became follower at term 1
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 switched to configuration voters=(1)
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 switched to configuration voters=(1 2)
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 switched to configuration voters=(1 2 3)
07:50:28 raftexample1 | {"level":"info","msg":"starting remote peer","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"starting remote peer","remote-peer-id":"1"}
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 became follower at term 0
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: newRaft 2 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 became follower at term 1
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 switched to configuration voters=(1)
07:50:28 raftexample3 | {"level":"info","msg":"started HTTP pipelining with remote peer","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample1 | {"level":"info","msg":"started HTTP pipelining with remote peer","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 switched to configuration voters=(1 2)
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 switched to configuration voters=(1 2 3)
07:50:28 raftexample2 | {"level":"info","msg":"starting remote peer","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"started HTTP pipelining with remote peer","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"started remote peer","remote-peer-id":"2"}
07:50:28 raftexample2 | {"level":"info","msg":"started remote peer","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream Message","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample1 | {"level":"debug","msg":"dial stream reader","from":"1","to":"2","address":"http://127.0.0.1:22379/raft/stream/msgapp/1"}
07:50:28 raftexample2 | {"level":"debug","msg":"dial stream reader","from":"2","to":"1","address":"http://127.0.0.1:12379/raft/stream/message/2"}
07:50:28 raftexample2 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"debug","msg":"dial stream reader","from":"2","to":"1","address":"http://127.0.0.1:12379/raft/stream/msgapp/2"}
07:50:28 raftexample2 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample1 | {"level":"info","msg":"added remote peer","local-member-id":"1","remote-peer-id":"2","remote-peer-urls":["http://127.0.0.1:22379"]}
07:50:28 raftexample1 | {"level":"info","msg":"starting remote peer","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"started HTTP pipelining with remote peer","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"started remote peer","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"added remote peer","local-member-id":"1","remote-peer-id":"3","remote-peer-urls":["http://127.0.0.1:32379"]}
07:50:28 raftexample3 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"info","msg":"started remote peer","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"debug","msg":"dial stream reader","from":"3","to":"1","address":"http://127.0.0.1:12379/raft/stream/msgapp/3"}
07:50:28 raftexample3 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream Message","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"debug","msg":"dial stream reader","from":"3","to":"1","address":"http://127.0.0.1:12379/raft/stream/message/3"}
07:50:28 raftexample3 | {"level":"info","msg":"added remote peer","local-member-id":"3","remote-peer-id":"1","remote-peer-urls":["http://127.0.0.1:12379"]}
07:50:28 raftexample3 | {"level":"info","msg":"starting remote peer","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"started HTTP pipelining with remote peer","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream Message","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"debug","msg":"dial stream reader","from":"1","to":"3","address":"http://127.0.0.1:32379/raft/stream/message/1"}
07:50:28 raftexample1 | {"level":"debug","msg":"dial stream reader","from":"1","to":"3","address":"http://127.0.0.1:32379/raft/stream/msgapp/1"}
07:50:28 raftexample2 | {"level":"info","msg":"added remote peer","local-member-id":"2","remote-peer-id":"1","remote-peer-urls":["http://127.0.0.1:12379"]}
07:50:28 raftexample2 | {"level":"info","msg":"starting remote peer","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"started HTTP pipelining with remote peer","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"started remote peer","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"debug","msg":"dial stream reader","from":"2","to":"3","address":"http://127.0.0.1:32379/raft/stream/msgapp/2"}
07:50:28 raftexample2 | {"level":"info","msg":"added remote peer","local-member-id":"2","remote-peer-id":"3","remote-peer-urls":["http://127.0.0.1:32379"]}
07:50:28 raftexample2 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"debug","msg":"peer deactivated again","peer-id":"1","error":"failed to dial 1 on stream MsgApp v2 (dial tcp 127.0.0.1:12379: connect: connection refused)"}
07:50:28 raftexample2 | {"level":"debug","msg":"dial stream reader","from":"2","to":"1","address":"http://127.0.0.1:12379/raft/stream/msgapp/2"}
07:50:28 raftexample2 | {"level":"debug","msg":"peer deactivated again","peer-id":"1","error":"failed to dial 1 on stream Message (dial tcp 127.0.0.1:12379: connect: connection refused)"}
07:50:28 raftexample2 | {"level":"debug","msg":"dial stream reader","from":"2","to":"1","address":"http://127.0.0.1:12379/raft/stream/message/2"}
07:50:28 raftexample2 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream Message","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"debug","msg":"dial stream reader","from":"2","to":"3","address":"http://127.0.0.1:32379/raft/stream/message/2"}
07:50:28 raftexample2 | {"level":"debug","msg":"peer deactivated again","peer-id":"3","error":"failed to dial 3 on stream MsgApp v2 (dial tcp 127.0.0.1:32379: connect: connection refused)"}
07:50:28 raftexample2 | {"level":"debug","msg":"dial stream reader","from":"2","to":"3","address":"http://127.0.0.1:32379/raft/stream/msgapp/2"}
07:50:28 raftexample3 | {"level":"info","msg":"started remote peer","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"added remote peer","local-member-id":"3","remote-peer-id":"2","remote-peer-urls":["http://127.0.0.1:22379"]}
07:50:28 raftexample3 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"debug","msg":"dial stream reader","from":"3","to":"2","address":"http://127.0.0.1:22379/raft/stream/msgapp/3"}
07:50:28 raftexample3 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream Message","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"debug","msg":"dial stream reader","from":"3","to":"2","address":"http://127.0.0.1:22379/raft/stream/message/3"}
07:50:28 raftexample3 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"set message encoder","from":"3","to":"2","stream-type":"stream MsgApp v2"}
07:50:28 raftexample3 | {"level":"info","msg":"peer became active","peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream MsgApp v2","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"set message encoder","from":"3","to":"2","stream-type":"stream Message"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream reader with remote peer","stream-reader-type":"stream Message","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"debug","msg":"dial stream reader","from":"1","to":"2","address":"http://127.0.0.1:22379/raft/stream/message/1"}
07:50:28 raftexample1 | {"level":"debug","msg":"peer deactivated again","peer-id":"3","error":"failed to dial 3 on stream Message (dial tcp 127.0.0.1:32379: connect: connection refused)"}
07:50:28 raftexample1 | {"level":"debug","msg":"dial stream reader","from":"1","to":"3","address":"http://127.0.0.1:32379/raft/stream/message/1"}
07:50:28 raftexample3 | {"level":"info","msg":"set message encoder","from":"3","to":"1","stream-type":"stream MsgApp v2"}
07:50:28 raftexample3 | {"level":"info","msg":"peer became active","peer-id":"1"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream MsgApp v2","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"info","msg":"set message encoder","from":"3","to":"1","stream-type":"stream Message"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream Message","local-member-id":"3","remote-peer-id":"1"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"started stream writer with remote peer","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"set message encoder","from":"1","to":"2","stream-type":"stream Message"}
07:50:28 raftexample1 | {"level":"info","msg":"peer became active","peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"set message encoder","from":"1","to":"3","stream-type":"stream Message"}
07:50:28 raftexample1 | {"level":"info","msg":"peer became active","peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream Message","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"set message encoder","from":"1","to":"3","stream-type":"stream MsgApp v2"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream MsgApp v2","local-member-id":"1","remote-peer-id":"3"}
07:50:28 raftexample1 | {"level":"info","msg":"set message encoder","from":"1","to":"2","stream-type":"stream MsgApp v2"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream MsgApp v2","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample1 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream Message","local-member-id":"1","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream Message","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample3 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"3","remote-peer-id":"2"}
07:50:28 raftexample2 | {"level":"info","msg":"peer became active","peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream Message","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"set message encoder","from":"2","to":"3","stream-type":"stream Message"}
07:50:28 raftexample2 | {"level":"info","msg":"peer became active","peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"set message encoder","from":"2","to":"1","stream-type":"stream Message"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"set message encoder","from":"2","to":"1","stream-type":"stream MsgApp v2"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream MsgApp v2","local-member-id":"2","remote-peer-id":"1"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream Message","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream MsgApp v2","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample2 | {"level":"info","msg":"set message encoder","from":"2","to":"3","stream-type":"stream MsgApp v2"}
07:50:28 raftexample2 | {"level":"info","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream MsgApp v2","local-member-id":"2","remote-peer-id":"3"}
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 switched to configuration voters=(1 2 3)
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 switched to configuration voters=(1 2 3)
07:50:28 raftexample1 | raft2025/07/02 07:50:28 INFO: 1 switched to configuration voters=(1 2 3)
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 switched to configuration voters=(1 2 3)
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 switched to configuration voters=(1 2 3)
07:50:28 raftexample2 | raft2025/07/02 07:50:28 INFO: 2 switched to configuration voters=(1 2 3)
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 switched to configuration voters=(1 2 3)
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 switched to configuration voters=(1 2 3)
07:50:28 raftexample3 | raft2025/07/02 07:50:28 INFO: 3 switched to configuration voters=(1 2 3)
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 is starting a new election at term 1
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 became candidate at term 2
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 [logterm: 1, index: 3] sent MsgVote request to 2 at term 2
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 [logterm: 1, index: 3] sent MsgVote request to 3 at term 2
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 received MsgVoteResp from 1 at term 2
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 has received 1 MsgVoteResp votes and 0 vote rejections
07:50:30 raftexample2 | raft2025/07/02 07:50:30 INFO: 2 [term: 1] received a MsgVote message with higher term from 1 [term: 2]
07:50:30 raftexample3 | raft2025/07/02 07:50:30 INFO: 3 [term: 1] received a MsgVote message with higher term from 1 [term: 2]
07:50:30 raftexample3 | raft2025/07/02 07:50:30 INFO: 3 became follower at term 2
07:50:30 raftexample2 | raft2025/07/02 07:50:30 INFO: 2 became follower at term 2
07:50:30 raftexample3 | raft2025/07/02 07:50:30 INFO: 3 [logterm: 1, index: 3, vote: 0] cast MsgVote for 1 [logterm: 1, index: 3] at term 2
07:50:30 raftexample2 | raft2025/07/02 07:50:30 INFO: 2 [logterm: 1, index: 3, vote: 0] cast MsgVote for 1 [logterm: 1, index: 3] at term 2
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 received MsgVoteResp from 3 at term 2
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 has received 2 MsgVoteResp votes and 0 vote rejections
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: 1 became leader at term 2
07:50:30 raftexample1 | raft2025/07/02 07:50:30 INFO: raft.node: 1 elected leader 1 at term 2
07:50:30 raftexample2 | raft2025/07/02 07:50:30 INFO: raft.node: 2 elected leader 1 at term 2
07:50:30 raftexample3 | raft2025/07/02 07:50:30 INFO: raft.node: 3 elected leader 1 at term 2
```

我们可以尝试在系统中写入一个 kv 对
```
curl -L http://127.0.0.1:12380/my-key -XPUT -d foo
```

接下来我们停掉一个节点来测试系统的可用性：
```
goreman run stop raftexample2
```

停止掉之后，我们可以看到集群中 raftexample1 和 raftexample3 节点会打连不上 raftexample2 的日志

```
23:24:05 raftexample1 | {"level":"debug","msg":"peer deactivated again","peer-id":"2","error":"failed to dial 2 on stream Message (dial tcp 127.0.0.1:22379: connect: connection refused)"}
23:24:05 raftexample3 | {"level":"debug","msg":"peer deactivated again","peer-id":"2","error":"failed to dial 2 on stream Message (dial tcp 127.0.0.1:22379: connect: connection refused)"}
```

这时候我们可以继续对 raftexample1、raftexample3 节点进行读写操作
```
curl -L http://127.0.0.1:12380/my-key -XPUT -d bar
curl -L http://127.0.0.1:32380/my-key
```

最后我们启动 raftexample2 节点，并读取 my-key

```
goreman run start raftexample2
curl -L http://127.0.0.1:22380/my-key
```

可以看到可以读到对 raftexample2 curl GET my-key 的值为 bar，也就是 raftexample2 即使故障了，重启时候还是能通过 raft 共识协议与其他节点保持数据一致。
