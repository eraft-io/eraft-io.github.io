### 概述
Raft 是一种容易理解的分布式共识算法，我们可以基于它设计出可以容灾的多节点分布式复制组。我们团队基于 C++ 实现了一个 Raft 算法库 eraft [https://github.com/eraft-io/eraft](https://github.com/eraft-io/eraft) ，目前项目已被 [https://raft.github.io](https://raft.github.io) 收录，并且开发人员为国内名校存储实验室的研究生以及大厂存储团队开发人员。下面我们将带着大家结合理论以及我们的代码实现来深入学习 Raft 选举、日志复制、成员变更、Leader 变更、基于 Raft 实现 RocksDB 分布式复制组等话题。
### Raft 的 Leader 选举流程
Raft 协议的工作模式是一个 Leader 节点和多个 Follower 节点的模式。在 Raft 协议中，每个节点都维护了一个状态机。该状态机有 3 种状态：Leader、Follower 和 Candidate。在任意时间，集群中的任意节点都处于这三个状态之一。
![Raft节点状态转换图](https://images.gitbook.cn/7188ef70-0bf7-11ec-83cb-07ac0d3b70bf)
Leader 节点的主要工作有两个：一个是处理所有 Client 的请求，另一个是定期向 Follower 节点发送心跳信息。当收到客户端写入请求时，Leader 节点会在本地追加一个日志，然后将其封装成消息发送到集群中的其他 Follower 节点。Follower 节点收到相应消息并对其进行响应。Leader 如果收到超过半数节点的响应信息，则认为该条日志已被 committed，可以对客户端返回响应。Leader 定期向 Follower 发送心跳信息是为了防止集群其他 Follower 节点的选举计时器超时而导致触发新一轮选举。

Follower 节点不会处理任何请求。Follower 节点只是简单地响应来自 Leader 节点或者 Candidate节点的请求。Follower 节点会将客户端的请求重定向给集群的 Leader 节点。

Candidate 节点是由 Follower 节点转换而来。当 Follower 节点长时间没有收到来自Leader 节点发送的心跳信息，则该节点的选举计时器就会过期，同时将自身状态变为 Candidate 节点，发起新一轮选举。

在 Raft 协议中有两个时间控制 Leader 选举发生：选举超时时间 (election timeout) 和心跳超时时间 (heartbeat timeout)。选举超时时间是指：Follower 在 election timeout 时间内没有收到 Leader 的心跳信息，则切换为 Candidate 开始新一轮的选举。election timeout 一般设置为150ms~300ms 的随机数，也即每个节点的选举超时时间一般都不同。心跳超时时间则是指 Leader 向 Follower 节点发送心跳消息的间隔时间。

下面我们结合代码梳理一下选举流程

1集群初始化时，所有节点为Follower。
```
    RaftContext::RaftContext(Config &c) {
        ...
        this->BecomeFollower(0, NONE);  // become follower
        this->randomElectionTimeout_ = this->electionTimeout_ + 
        RandIntn(this->electionTimeout_); // generate random election timeout
        ...
        this->leadTransferee_ = NONE;
    }
```

Follower 节点会收到 Leader 节点和 Candidate 发送的有效 RPCs 信息来保持 Follower 状态。Leader 节点会周期性地发送心跳信息给所有 Follower 节点来维持自己的 Leader 状态。

```
      void RaftContext::Tick() {
            switch (this->state_)
            {
                case NodeState::StateFollower:
                {
                    this->TickElection();
                    break;
                }
                case NodeState::StateCandidate:
                {
                    this->TickElection();
                    break;
                }
                case NodeState::StateLeader:
                {
                    if(this->leadTransferee_ != NONE) {
                        this->TickTransfer();
                    }
                    this->TickHeartbeat(); // leader send periodic heartbeat
                    break;
                }
            }
        }
     
        // bcast all heartbeat to all followers
        void RaftContext::BcastHeartbeat() {
          SPDLOG_INFO("bcast heartbeat ");
          for (auto peer : this->prs_) {
            if (peer.first == this->id_) {
              continue;
            }
            SPDLOG_INFO("send heartbeat to peer " + std::to_string(peer.first));
            this->SendHeartbeat(peer.first);
          }
        }
```

2.在经过一段时间后 (election timeout) Follower 没有收到 Leader 的心跳信息，则认为 Leader 出现故障，Follower 切换为 Candidate 发起选举。

```
    //if electionElapsed_ >= randomElectionTimeout_, election timeoout, send 
    // MsgHup to trigger a new election
        void RaftContext::TickElection() {
          this->electionElapsed_++;
          if (this->electionElapsed_ >=
              this->randomElectionTimeout_) {  // election timeout
            SPDLOG_INFO("election timeout");
        
            this->electionElapsed_ = 0;
            eraftpb::Message msg;
            msg.set_msg_type(eraftpb::MsgHup);
            this->Step(msg);
          }
        }
```

3.Raft 协议中每次发起选举时，每个 Follower 都会递增当前任期 (currentTerm)，转换为 Candidate 状态，并给自己投票。

```
    void RaftContext::BecomeCandidate() {
      this->state_ = NodeState::StateCandidate;
      this->lead_ = NONE;
      this->term_++;
      this->vote_ = this->id_;
      this->votes_ = std::map<uint64_t, bool>{};
      this->votes_[this->id_] = true;  // vote for self
      SPDLOG_INFO("node become candidate at term " + std::to_string(this->term_));
    }
```

Candidate 会发送 RequestVoteRPC 消息给集群中的其他节点。

```
    bool RaftContext::DoElection() {
      SPDLOG_INFO("node start do election");
      this->BecomeCandidate();
      this->heartbeatElapsed_ = 0;
      this->randomElectionTimeout_ =
          this->electionTimeout_ + RandIntn(this->electionTimeout_);
      if (this->prs_.size() == 1) {
        this->BecomeLeader();
        return true;
      }
      uint64_t lastIndex = this->raftLog_->LastIndex();
      auto resPair = this->raftLog_->Term(lastIndex);
      uint64_t lastLogTerm = resPair.first;
    
      for (auto peer : this->prs_) {
        if (peer.first == this->id_) {
          continue;
        }
        this->SendRequestVote(peer.first, lastIndex, lastLogTerm);
      }
    }
```

4.Candidate 节点会保持 Candidate 状态直到以下三种情况发生：

- Candidate 节点赢得选举成为 Leader 节点；
- 其他 Candidate 赢得选举成为 Leader 节点；
- 选举超时时间 (election timeout) 过去了，还没有选出 Leader 。当一个 Candidate 收到超过半数节点的选票，则它成为 Leader。Candidate 成为 Leader 后，它会向其他节点发送心跳消息来确立它的权限并阻止新的选举。
```
    bool RaftContext::HandleRequestVoteResponse(eraftpb::Message m) {
     SPDLOG_INFO("handle request vote response from peer " +
                 std::to_string(m.from()));
     if (m.term() != NONE && m.term() < this->term_) {
       return false;
     }
     this->votes_[m.from()] = !m.reject();
     uint8_t grant = 0;
     uint8_t votes = this->votes_.size();
     uint8_t threshold = this->prs_.size() / 2;
     for (auto vote : this->votes_) {
       if (vote.second) {
         grant++;
       }
     }
     if (grant > threshold) {
       this->BecomeLeader();
     } else if (votes - grant > threshold) {
       this->BecomeFollower(this->term_, NONE);
     }
    }
```

在等待投票的过程中， Candidate 可能会收到来自另外一个节点的成为 Leader 的 AppendEntries RPC 请求消息。如果 Leader 的任期号 (term) 大于 Candidate 当前记录的任期号 (current term) ，Candidate 将认可 Leader 是合法的，并转换为 Follower 状态。如果 Leader 的任期号 (term) 小于 Candidate 当前记录的任期号 (current term)，Candidate 将拒绝 AppendEntries RPC 请求并保持当前状态。

```
     bool RaftContext::HandleAppendEntries(eraftpb::Message m) {
          SPDLOG_INFO("handle append entries " + MessageToString(m));
        
          if (m.term() != NONE && m.term() < this->term_) {
            this->SendAppendResponse(m.from(), true, NONE, NONE);
            return false;
          }
            ...
     }
```
另一种可能的结果是 Candidate 既没有赢得选举也没有输：如果很多 Follower 同时成为 Candidate，则可能会分裂选票，从而导致没有 Candidate 将获得大多数票。当发生这种情况时，每个 Candidate 将超时并通过增加其任期来启动另一轮 RequestVote RPC 来开始新的选举。 然而，如果没有额外的措施，分裂选票的情况可能会无限重复。

Raft 的 election timeout 是随机的，这是为了减少分离选票的情况发生。election timeouts 一般会在 150-300ms 之间随机取值。这表明在大多数情况下只有一个节点会超时。它赢得选举并在其他服务器超时之前发送心跳。同样的机制也用于处理分裂投票。每个 Candidate 在选举开始时重新随机设置 election timeouts，并在下一次选举开始之前等待该超时过去。这降低了在新的选举中再次出现分裂投票的可能性。

### Raft 的日志复制流程
上一节介绍了 Leader 的选取流程。Leader 会处理来自客户端 Client 的请求，并将客户端更新操作以消息 ( Append Entries 消息) 的形式发送到集群中所有 Follower 节点。本节将介绍 Raft 协议日志复制的流程。

#### 日志复制

假设集群中有 A，B，C 三个节点，其中节点 A 为 Leader，此时有一个客户端发送了一个更新操作到集群：

1. 当收到客户端的请求，节点 A 会将更新操作记录到本地 Log 中
2. 节点 A 向其他节点发送 Append Entries 消息，消息中记录了 Leader 节点最近收到的请求日志
3. B,C 收到来自 Leader 的 Append Entries 消息时，会将该操作记录到本地 Log 中，并返回响应消息
4. 当 A 收到超过半数的响应消息时，会认为集群中有半数以上的节点已经记录了该更新操作。Leader 节点将该日志设置为已提交 (committed)
5. Leader 向客户端返回响应，并通知 Follower 节点该日志已被提交
6. Follower 收到消息时，才会认为该日志已被提交

如果 Follower 宕机或者运行很慢或者消息包丢失，Leader 将会不停地重新发送 Append Entries 消息，直到所有 Follower 都存储了所有日志条目。

```
    // Leader appends the command to its log as a new entry
    void RaftContext::AppendEntries(
        std::vector<std::shared_ptr<eraftpb::Entry> > entries) {
      SPDLOG_INFO("append entries size " + std::to_string(entries.size()));
      uint64_t lastIndex = this->raftLog_->LastIndex();
      uint64_t i = 0;
      // push entries to raftLog
      for (auto entry : entries) {
        entry->set_term(this->term_);
        entry->set_index(lastIndex + i + 1);
        if (entry->entry_type() == eraftpb::EntryConfChange) {
          if (this->pendingConfIndex_ != NONE) {
            continue;
          }
          this->pendingConfIndex_ = entry->index();
        }
        this->raftLog_->entries_.push_back(*entry);
      }
      this->prs_[this->id_]->match = this->raftLog_->LastIndex();
      this->prs_[this->id_]->next = this->prs_[this->id_]->match + 1;
      this->BcastAppend();
      if (this->prs_.size() == 1) {
        this->raftLog_->commited_ = this->prs_[this->id_]->match;
      }
    }
    // Leader send AppendEntries RPCs in parallel to each of the other servers
    void RaftContext::BcastAppend() {
      for (auto peer : this->prs_) {
        if (peer.first == this->id_) {
          continue;
        }
        this->SendAppend(peer.first);
      }
    }
```

#### 日志一致性

当一个新的 Leader 被选举出来，它的日志可能会其他 Follower 不一致，这时候需要一个机制来保证日志的一致性。集群中每个节点都会维护一个本地 log 用于记录操作，另外，每个节点还会维护两个索引值：commitIndex 和 lastApplied。commitIndex 表示当前节点已知的，最大的，已提交的日志索引。lastApplied 索引表示当前节点最后一条被应用到状态机的日志索引，当 commitIndex 大于 lastApplied 时，会将 lastApplied 加 1，并将 lastApplied 对应的日志应用到状态机。Leader 节点还需要知道每个 Follower 节点的日志复制到哪个位置，从而决定下次发送 Append Entries 消息中包含哪些日志记录。为此 Leader 会维护两个数组：nextIndex[ ] 和 matchIndex[ ]。nextIndex[ ] 记录了需要发给每个 Follower 的下一条日志的索引值。matchIndex[ ] 记录了已经复制给每个 Follower 的最大的日志索引值。

```
    void RaftContext::LeaderCommit() {
      std::vector<uint64_t> match;
      match.resize(this->prs_.size());
      uint64_t i = 0;
      for (auto prs : this->prs_) {
        match[i] = prs.second->match;
        i++;
      }
      std::sort(match.begin(), match.end());
      uint64_t n = match[(this->prs_.size() - 1) / 2];
      if (n > this->raftLog_->commited_) {
        auto resPair = this->raftLog_->Term(n);
        uint64_t logTerm = resPair.first;
        if (logTerm == this->term_) {
          // commit 条件，半数节点以上
          this->raftLog_->commited_ = n;
          this->BcastAppend();
        }
      }
      SPDLOG_INFO("leader commit on log index " +
                  std::to_string(this->raftLog_->commited_));
    }
```

下面通过一个示例来说明 nextIndex[ ] 和 matchIndex[ ] 在日志复制过程的作用。假设有三个节点 A、B、C，其中节点 A 为 term=1 的 Leader，节点 C 由于宕机导致一段时间没有与 Leader 同步日志，此时节点 C 的 log 并不包含全部已提交日志，此时 Leader 记录的 nextIndex[ ] 和 matchIndex[ ] 的值如下。

| 节点 | nextIndex | matchIndex  |
|--|--|--|
| A | 4 | 3  |
| B | 4 | 3 |
| C | 2 |  1|

因为 Leader 中记录了节点 C 的 nextIndex=2，所以会向节点 C 发送 index=2 的 Append Entries 消息。节点 C 收到消息之后，会将日志记录到本地 log 中，并向 Leader 发送响应。
Leader 收到响应后，会递增节点 C 对应的 nextIndex 和 matchIndex。
| 节点 | nextIndex | matchIndex  |
|--|--|--|
| A | 4 | 4  |
| B | 4 | 3 |
| C | 3 |  2|

如果在上述例子中，节点 C 故障恢复后，节点 A 宕机后重启，导致节点 B 成为 term=2 的新 Leader，此时节点 B 不知道旧 Leader 节点的 nextIndex 和 matchIndex，所以新的 Leader 会重置 nextIndex[ ] 和 matchIndex[ ] ,其中 nextIndex[ ] 全部重置为新 Leader 节点自身最后一条已提交日志的 index 值，而 matchIndex[ ] 全部重置为 0。
| 节点 | nextIndex | matchIndex  |
|--|--|--|
| A | 4 | 0  |
| B | 4 | 0 |
| C | 4 |  0|


新的 Leader 会发送新的 Append Entries 消息 (term=2,index=4)。对于节点 C，它没有 index=2，index=3 两条日志，因此追加失败。
Leader 收到节点 C 追加日志失败的响应，会将 nextIndex 减 1，即发送 (term=2,index=3) 的Append Entries 消息给节点 C 。循环反复，不断减小 nextIndex 的值，直到节点 C 返回追加成功的响应。

### Raft 成员变更
到目前为止，我们都假设集群的配置（加入到一致性算法的服务器集合）是固定不变的。但是在实践中，是有可能需要改变集群的配置的，例如替换那些宕机的机器或者改变副本数量。也有一种办法，可以通过暂停整个集群，更新所有配置，然后重启整个集群的方式来实现配置变更，但是在更改的时候集群会不可用，这实际的生产环境是不行的。另外，如果存在手工操作步骤，那么就会有操作失误的风险。为了避免这样的问题，我们就非常有必要实现的自动化配置变更了。

成员变更在一致性算法中算比较复杂的部分，因为我们要求再配置变更的过程中是不允许出现同一个任期里面有两个 Leader 被同时选举出来的。然而，任何从旧的配置直接转换到新的配置的方案都是不安全的。一次性原子的转换所有的服务器是不可能的，在转换过程中可能出现两个不相交的 majority，导致同一个任期内选举出两个 Leader，进而导致同一个 index 的日志不一样，违反一致性协议。

![two disjoint majorities](https://images.gitbook.cn/23778380-0bf9-11ec-ad04-c1ce2acdcd5d)
Raft 作者提出了一种简单的解决办法，也就是一次配置变更只增加或删除一个成员，这样就保证了任何时刻至多出现一个 Leader, 确保了成员变更的安全性。

![two disjoint majorities](https://images.gitbook.cn/3a4f71d0-0bf9-11ec-83cb-07ac0d3b70bf)

在 eraft 里面，成员变更的主要思路是提交一个成员变更的日志条目到 raft 状态机中，等到日志 commit，日志 apply 的时候进行实际的配置变更操作，这样可以保证所有节点变更的配置是一致的。

接下来我们结合 eraft 代码实现来分析这个过程。

首先我们来看下客户端的代码，客户端接到命令行参数，包装到 ChangePeerRequest 里面，
```
       // Kv/kv_cli.cc
       raft_cmdpb::ChangePeerRequest confChange;
       std::string confChangeType = std::string(argv[3]);
       if (confChangeType == "add")
         confChange.set_change_type(eraftpb::AddNode);
       else if (confChangeType == "remove")
         confChange.set_change_type(eraftpb::RemoveNode);
       metapb::Peer* pr = new metapb::Peer();
       pr->set_addr(std::string(argv[4]));
       pr->set_id(std::atoi(argv[5]));
       pr->set_store_id(std::atoi(argv[5]));
       confChange.set_allocated_peer(pr);
       raftClient->PeerConfChange(std::string(argv[1]), confChange);
```

然后将包装好的请求通过 raftClient 通过 rpc 发送到服务端

```

    bool RaftClient::PeerConfChange(std::string addr,
                                    raft_cmdpb::ChangePeerRequest& request) {
      std::shared_ptr<RaftConn> conn = this->GetConn(addr, 1);
      std::unique_ptr<TinyKv::Stub> stub_(TinyKv::NewStub(conn->GetChan()));
      raft_cmdpb::ChangePeerResponse response;
      grpc::ClientContext context;
      stub_->PeerConfChange(&context, request, &response);
      return true;
    }
```

在服务端收到了请求之后，就是我们接下来要做的请求处理，首先我们要将请求封装成一个 RaftMessage，并且定义消息类型为 RaftConfChange，将封装好的消息通过 raft 路由发送（push_back）到我们消息处理队列 peerSender，在之前还要进行一次消息的封装，因为消息队列是处理所有的日志，并不都是 RaftMessage 类型。将我们的 RaftMessage 封装到 Msg 当中，并且定义 Msg 的类型为 MsgTypeRaftMessage。

```
    // Kv/server/server.cc
    Status Server::PeerConfChange(ServerContext* context,
                                  const raft_cmdpb::ChangePeerRequest* request,
                                  raft_cmdpb::ChangePeerResponse* response) {
      // 构造配置变更的消息，发送到 raft group
      std::shared_ptr<raft_serverpb::RaftMessage> sendMsg =
          std::make_shared<raft_serverpb::RaftMessage>();
      sendMsg->set_data(request->SerializeAsString());
      sendMsg->set_region_id(1);
      sendMsg->set_raft_msg_type(raft_serverpb::RaftConfChange);
      this->Raft(context, sendMsg.get(), nullptr);
      return Status::OK;
    }
    // Kv/server/router.cc
    bool RaftstoreRouter::SendRaftMessage(const raft_serverpb::RaftMessage* msg) {
      raft_serverpb::RaftMessage* raftmsg = new raft_serverpb::RaftMessage(*msg);
      SPDLOG_INFO("send raft message type " +
                  eraft::MsgTypeToString(raftmsg->message().msg_type()));
      Msg m = Msg(MsgType::MsgTypeRaftMessage, msg->region_id(), raftmsg);
      return this->router_->Send(msg->region_id(), m);
    }
```

到了这里，我们已经将我们请求封装成了 Msg 并放入到消息处理队列，接下来就是处理消息了。消息处理是一个单独的线程，主要看 HandleMsg 是如何处理消息，和处理完消息发送。

```
    // Kv/server/raft_worker.cc
    void RaftWorker::Run(Queue<Msg>& qu) {
      Logger::GetInstance()->DEBUG_NEW("raft worker start running!", __FILE__,
                                       __LINE__, "RaftWorker::Run");
      std::map<uint64_t, std::shared_ptr<PeerState_> > peerStMap;
      while (true) {
        auto msg = qu.Pop();
        // handle m, call PeerMessageHandler
        std::shared_ptr<PeerState_> peerState =
            RaftWorker::GetPeerState(peerStMap, msg.regionId_);
        PeerMsgHandler pmHandler(peerState->peer_, RaftWorker::ctx_);
        pmHandler.HandleMsg(msg);
        // get peer state, and handle raft ready
        PeerMsgHandler pmHandlerRaftRd(peerState->peer_, RaftWorker::ctx_);
        pmHandlerRaftRd.HandleRaftReady();
      }
    }
```

首先根据 Msg 的类型选择如何处理，比如我们这里应该是 MsgTypeRaftMessage，拿到 RaftMessage，根据类型 RaftConfChange，再进一步反序列化拿到 ChangePeerRequest，也就是我们最开始的客户端请求类型，再将我们需要的信息封装成 ConfChange，通过 ProposeConfChange 处理，将 ConfChange 消息序列化为 Message，将存储的消息类型设置为 EntryConfChange，也就是里面消息的类型，并非 Message 的类型，Message 的类型设置为 MsgPropose，因为 raft 配置变更的消息是和普通日志在一起处理，所以普通日志为 EntryNormal，作以区分。

```
    //Kv/server/peer_mag_handler.cc
    void PeerMsgHandler::HandleMsg(Msg m) {
      switch (m.type_) {
        case MsgType::MsgTypeRaftMessage: {
          if (m.data_ != nullptr) {
            try {
              auto raftMsg = static_cast<raft_serverpb::RaftMessage*>(m.data_);
              switch (raftMsg->raft_msg_type()) {
    			  case raft_serverpb::RaftConfChange: {
                  // 构造一个 日志条目 ProposeRaftCommand(), 提交到状态机
                  std::shared_ptr<raft_cmdpb::ChangePeerRequest> peerChange =
                      std::make_shared<raft_cmdpb::ChangePeerRequest>();
                  peerChange->ParseFromString(raftMsg->data());
                  {
                    eraftpb::ConfChange confChange;
                    confChange.set_node_id(peerChange->peer().id());
                    confChange.set_context(peerChange->peer().addr());
                    confChange.set_change_type(peerChange->change_type());
                    this->peer_->raftGroup_->ProposeConfChange(confChange);
                  }
                  break;
                }
              }
            }
          }
        }
      }
    }
    // RaftCore/src/raw_node.cc
    void RawNode::ProposeConfChange(eraftpb::ConfChange cc) {
      std::string data = cc.SerializeAsString();
      eraftpb::Message msg;
      /*   package msg */
      this->raft->Step(msg);
    }
```

那么接下来就是将消息放入到日志中，也就是 AppendEntry。注意这一步是 Leader 执行，还未涉及到 Follower，在 Leader 处理了日志之后，会将日志发送给 Follower，Follower 执行的操作也就是前面所有的操作，只是在 Step 中选择 StepFollower。

```
    // RaftCore/src/raft.cc
    bool RaftContext::Step(eraftpb::Message m) {
      switch (this->state_) {
        case NodeState::StateFollower: {
          this->StepFollower(m);
          break;
        }
        case NodeState::StateCandidate: {
          this->StepCandidate(m);
          break;
        }
        case NodeState::StateLeader: {
          this->StepLeader(m);
          break;
        }
      }
      return true;
    }
```

leader 拿到消息后就是 AppendEntry。这里做的就是将消息添加到我们的 log（具体就是 entries_）中。然后更新 raftLog_ 的 nextindex (对于每一台服务器，发送到该服务器的下一个日志条目的索引（初始值为领导者最后的日志 条目的索引 +1）和 matchIndex (对于每一台服务器，已知的已经复制到该服务器的最高日志条目的索引（初始值为 0，单调递增）)。然后再将 log 发送给配置中所有的 Follower。

```
    // RaftCore/src/raft.cc
    void RaftContext::AppendEntry(eraftpb::Message m) {
      uint64_t lastIndex = this->raftLog_->LastIndex();
      eraftpb::Entry entry;
      if (m.temp_data() != "") {
        this->raftLog_->entries_.push_back(entry);
      } else {
      }
      this->prs_[this->id_]->match = this->raftLog_->LastIndex();
      this->prs_[this->id_]->next = this->prs_[this->id_]->match + 1;
      this->BcastAppend();
      if (this->prs_.size() == 1) {
        this->raftLog_->commited_ = this->prs_[this->id_]->match;
      }
    }
```

发送给 Follower 是根据每个 Follower 的情况发送消息的，因为每个 Follower 已经接收的消息是不同的，由于网络延迟、丢包、分区等原因不可能保证 Follower 和 Leader 时刻同步。所以这就需要再发送日志的时候根据 Follower 的状态发送。prevIndex（紧邻新日志条目之前的那个日志条目的索引），prevLogTerm（紧邻新日志条目之前的那个日志条目的任期）。我们需要先找到 Follower紧邻新日志条目之前的那个日志条目（也就是 Follower 已经接收了的）索引和任期号，然后将这之后的日志全部打包到 Message 队列当中发送出去。

```
    //RaftCore/src/raft.cc
    bool RaftContext::SendAppend(uint64_t to) {
      uint64_t prevIndex = this->prs_[to]->next - 1;
      uint64_t prevLogTerm = this->raftLog_->Term(prevIndex);
      int64_t n = this->raftLog_->entries_.size();
      eraftpb::Message msg;
      /*  package msg  */
      for (uint64_t i = this->raftLog_->ToSliceIndex(prevIndex + 1); i < n; i++) {
        eraftpb::Entry* e = msg.add_entries();
      }
      this->msgs_.push_back(msg);
      return true;
    }
```
那么 HandleMsg 就完成，接下来就是 HandleRaftReady。主要流程就是取出打包好的日志消息，再将日志消息通过 rpc 发送给每个 Follower，发送完之后 Leader 需要对消息进行处理，ApplyConfChange，将成员变更进行实现。

```
    // Kv/server/peer_msg_handler.cc
    void PeerMsgHandler::HandleRaftReady() {
      if (this->peer_->raftGroup_->HasReady()) {
        eraft::DReady rd = this->peer_->raftGroup_->EReady();
        // real send raft message to transport (grpc)
        this->peer_->Send(this->ctx_->trans_, rd.messages);
        if (rd.committedEntries.size() > 0) {
          std::shared_ptr<rocksdb::WriteBatch> kvWB =
              std::make_shared<rocksdb::WriteBatch>();
          for (auto entry : rd.committedEntries) {
            kvWB = this->Process(&entry, kvWB);
          }
    }
```
首先是日志 rpc 发送，在这里就是对消息进行打包设置，包括发送到哪、从哪来、消息任期、消息类型等。一直到发送，发送最后就是建立一个链接到接收消息的 server，也就是 Follower，那么到这里 Follower 就已经接收到 rpc 调用，开始执行消息，Follower 的步骤类似 Leader，也是消息处理。
```
    // Kv/server/peer.cc
    void Peer::Send(std::shared_ptr<Transport> trans,
                    std::vector<eraftpb::Message> msgs) {
      for (auto msg : msgs) {
        if (!this->SendRaftMessage(msg, trans)) {
        }
      }
    }
    // Kv/server/peer.cc
    bool Peer::SendRaftMessage(eraftpb::Message msg,
                               std::shared_ptr<Transport> trans) {
      std::shared_ptr<raft_serverpb::RaftMessage> sendMsg =
          std::make_shared<raft_serverpb::RaftMessage>();
      auto fromPeer = this->meta_;
      auto toPeer = this->GetPeerFromCache(msg.to());
    /*   package sendmsg   */
      for (auto ent : msg.entries()) {
        eraftpb::Entry* e = sendMsg->mutable_message()->add_entries()
      }
      // rpc
      return trans->Send(sendMsg);
    }
    // Kv/server/raft_client.cc
    bool RaftClient::Send(uint64_t storeID, std::string addr,
                          raft_serverpb::RaftMessage& msg) {
      std::shared_ptr<RaftConn> conn = this->GetConn(addr, msg.region_id());
      std::unique_ptr<TinyKv::Stub> stub_(TinyKv::NewStub(conn->GetChan()));
      Done done;
      grpc::ClientContext context;
      auto status = stub_->Raft(&context, msg, &done);
      {
        std::lock_guard<std::mutex> lck(this->mu_);
        conns_.erase(addr);
      }
      return true;
    }
```
Leader 发送完日志之后就是消息处理，如果是添加节点，就加入到配置中，删除就删除节点。
```
    // Kv/server/peer_msg_handler.cc
    std::shared_ptr<rocksdb::WriteBatch> PeerMsgHandler::Process(
        eraftpb::Entry* entry, std::shared_ptr<rocksdb::WriteBatch> wb) {
      switch (entry->entry_type()) {
        case eraftpb::EntryType::EntryConfChange: {
          eraftpb::ConfChange* cc = new eraftpb::ConfChange();
          cc->ParseFromString(entry->data());
          this->ProcessConfChange(entry, cc, wb);
          break;
      }
      return wb;
    }
    void PeerMsgHandler::ProcessConfChange(
        eraftpb::Entry* entry, eraftpb::ConfChange* cc,
        std::shared_ptr<rocksdb::WriteBatch> wb) {
      switch (cc->change_type()) {
        case eraftpb::ConfChangeType::AddNode: {
          metapb::Peer* peer = new metapb::Peer();
          this->peer_->InsertPeerCache(peer);
          break;
        }
        case eraftpb::ConfChangeType::RemoveNode: {
          this->peer_->RemovePeerCache(cc->node_id());
          break;
        }
      }
      this->peer_->raftGroup_->ApplyConfChange(*cc);
    }
    eraftpb::ConfState RawNode::ApplyConfChange(eraftpb::ConfChange cc) {
      eraftpb::ConfState confState;
      switch (cc.change_type()) {
        case eraftpb::AddNode: {
          this->raft->AddNode(cc.node_id());
          break;
        }
        case eraftpb::RemoveNode: {
          this->raft->RemoveNode(cc.node_id());
          break;
        }
      }
      return confState;
    }
```
### Raft 切主实现
#### 为什么我们需要进行切主 (Leader 变更)

1.有时候 Leader 所在的机器可能需要下线。
2.有时候集群中其他节点更适合当 Leader （机器负载低，更适合承担 Leader 的角色）。

#### 切主实现细节

1.老的 Leader 停止接受新的客户端请求
```
       // recived transfer leader message
       case raft_serverpb::RaftTransferLeader: {
       std::shared_ptr<raft_cmdpb::TransferLeaderRequest> tranLeader =
           std::make_shared<raft_cmdpb::TransferLeaderRequest>();
       tranLeader->ParseFromString(raftMsg->data());
       Logger::GetInstance()->DEBUG_NEW(
           "transfer leader with peer id = " +
               std::to_string(tranLeader->peer().id()),
           __FILE__, __LINE__, "PeerMsgHandler::HandleMsg");
       this->peer_->raftGroup_->TransferLeader(tranLeader->peer().id());
       break;
    }
    
    case eraftpb::MsgPropose: {
     if (this->leadTransferee_ == NONE) { // leadTransferee_ != NONE, stop accepting new client request.
       Logger::GetInstance()->DEBUG_NEW(
           "StepLeader -> m.data() " + m.temp_data(), __FILE__, __LINE__,
           "RaftContext::StepLeader");
       // append one
       this->AppendEntry(m);
     }
     break;
    }
```
2.老的 Leader 将目标节点的日志追上它自己的，正常的日志复制机制
```
    bool RaftContext::HandleTransferLeader(eraftpb::Message m) {
     if (m.from() == this->id_) {
       return false;
     }
     if (this->leadTransferee_ != NONE && this->leadTransferee_ == m.from()) {
       return false;
     }
     if (this->prs_[m.from()] == nullptr) {
       return false;
     }
     this->leadTransferee_ = m.from();
     this->transferElapsed_ = 0;
     if (this->prs_[m.from()]->match == this->raftLog_->LastIndex()) {
       this->SendTimeoutNow(m.from()); // prior leader sends a TimeoutNow request to the target server
     } else {
       this->SendAppend(m.from());
     }
    }
```
3.老的 Leader 发送一个 TimeoutNow 请求到目标服务器，这个请求会立马触发新的Leader 选举，目标服务器被选举成为 Leader
```
    case eraftpb::MsgTimeoutNow: {
      this->DoElection();
      break;
    }
```
### 基于 eraft 实现 RocksDB 分布式复制组
接下来，我们看下怎么基于 eraft 算法库实现一个简单的分布式 KV，下面是我们整个 kv 系统的架构。

KvCli 是我们测试的客户端，它通过 rpc 和我们的 kv\_server 交互，它会将封装好的 kv 数据请求发送到我们的 KvServer。KvServer 会将收到的请求发送到我们的请求队列中，并通过 HandleMsg 处理，这里 KvServer 会将消息提交到 RaftCore 进行交互，并且返回给 KvServer Ready 状态。等到用户写的 Kv 数据在集群的多数节点被复制，Leader 就会 commit 这条日志，同时我们可以将已经 commit 的日志（包含的用户写进来的 KV 数据），写入到 RocksDB 实例 kvDB_  中进行持久化。

RaftCore 中的日志我们会对其进行持久化，对应到一个 RocksDB 的实例 raftDB_。

![raft kv](https://images.gitbook.cn/d19778d0-0bf9-11ec-83cb-07ac0d3b70bf)

### 新节点加入集群怎么恢复数据
目前 eraft 库 kvserver 中没有实现快照恢复的功能，所以恢复实例的方法不同于论文。我们在做日志 compact 的时候只会压缩内存中的日志，并不会删除 raftDB_ 实例里面存储的 raft log 数据，那么如果一个实例落后主节点，我们怎么恢复呢？
```
    // 如果日志在内存中已经没合并了，我们会从 rocksdb 里面去扫 raftDB_ 里面持久化的 log 数据
    std::pair<uint64_t, bool> pair = this->storage_->Term(i); 
    if (!pair.second) {
        return std::make_pair<uint64_t, bool>(0, false);
    }
    ...
     if (!resPair.second) {
        // load log from db
        auto entries =
            this->raftLog_->storage_->Entries(prevIndex + 1, prevIndex + 2);
    
    ...
    
    std::vector<eraftpb::Entry> PeerStorage::Entries(uint64_t lo, uint64_t hi) {
      std::vector<eraftpb::Entry> ents;
    
      std::string startKey =
          Assistant::GetInstance()->RaftLogKey(this->region_->id(), lo);
      std::string endKey =
          Assistant::GetInstance()->RaftLogKey(this->region_->id(), hi);
    
      uint64_t nextIndex = lo;
    
      auto iter = this->engines_->raftDB_->NewIterator(rocksdb::ReadOptions());
      // scan from raftDB
      for (iter->Seek(startKey); iter->Valid(); iter->Next()) {
        if (Assistant::GetInstance()->ExceedEndKey(iter->key().ToString(),
                                                   endKey)) {
          break;
        }
        std::string val = iter->value().ToString();
        eraftpb::Entry ent;
        ent.ParseFromString(val);
    
        if (ent.index() != nextIndex) {
          break;
        }
    
        nextIndex++;
        ents.push_back(ent);
      }
      return ents;
    }
```
我们临时的解决办法比较简单，就是去扫 raftDB_ 里面存储的 raft log 数据，发送给落后的节点。eraft 库目前应用层的快照发送功能还没有实现，如果你对此感兴趣，欢迎提交 PR [https://github.com/eraft-io/eraft](https://github.com/eraft-io/eraft)。

### 参考

-  《CONSENSUS: BRIDGING THEORY AND PRACTICE》
-  etcd-raft https://github.com/etcd-io/etcd/tree/main/raft
-  tinykv https://github.com/tidb-incubator/tinykv


----------
本文首发于 GitChat，未经授权不得转载，转载需与 GitChat 联系。
