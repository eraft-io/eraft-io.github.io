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




### 启动参数介绍

### 运行 ETCD raft example 分布式 KV 服务
