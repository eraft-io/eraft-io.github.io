---
title: 动手学习分布式-基于Raft库，实现简单的分布式KV系统 (Golang eraftkv 版)
date: 2023-08-19 13:22:43
tags:
---

### 系统架构概览

上一章中，我们已经介绍了我们构建好的Raft库，它在eraft/raftcore目录下。现在我们要使用这个库来构建一个高可用的分布式KV存储系统。

![](/images/raft_overview.png)

让我们回到上图，这个图在我们一开始介绍Raft的时候讲到过，我们这一章就要实现这样一个系统。

### 对外接口定义

第一步我们来定义系统与客户端的交互接口，客户端可以发送Put和Get操作将KV数据写到系统中。我们需要定义这两个操作的RPC。我们将它们合并到一个RPC请求里面，定义如下：

```
// 

// client op type 

//

enum OpType {

    OpPut = 0;

    OpAppend = 1;

    OpGet = 2;

}



//

// client command request

//

message CommandRequest {

    string key = 1;

    string value = 2;

    OpType op_type = 3;

    int64  client_id = 4;

    int64  command_id = 5;

    bytes  context = 6;

}



//

// client command response

//

message CommandResponse {

    string value = 1;

    int64  leader_id = 2;

    int64  err_code = 3;

}


rpc DoCommand (CommandRequest) returns (CommandResponse) {}

```

其中OpType定义了我们支持的操作类型：put,Append,get。 客户端请求的内容定义在了CommandRequest中。CommandRequest中有我们的key, value以及操作类型，还有客户端id以及命令id,还有一个字节类型的context （context可以存放一些我们需要附加的不确定的内容）。

响应CommandResponse包括了返回值value ，leader_id字段（告诉我们当前Leader是哪个节点的。因为最开始客户端发送请求时，不知道那个节点被选成Leader 。我们通过一次试探请求拿到Leader节点的id,然后再次发送请求给Leader节点。），以及错误码err_code（记录可能出现的错误）。

客户端通过DoCommand RPC请求到我们的分布式KV系统。那我们的系统是怎么处理请求的呢？首先，我们来看看服务端的结构的定义。 mu是一把读写锁，用来对可能出现并发冲突的操作加锁。dead表示当前服务节点的状态，是不是存活。Rf比较重要，这个是只想我们之前构建的Raft结构的指针。applyCh是一个通道，用来从我们的算法库中返回已经apply的日志。我们的server拿到这个日之后需要apply到实际的状态机中。stm就是我们的状态机了，我们一会儿介绍。notifyChans是一个存储客户端响应的map，其中值是一个通道。KvServer在应用日志到状态机操作完之后，会给客户端发送响应到这个通道中。stopApplyCh用来停止我们的Apply操作。

### 服务端核心实现分析

```
type KvServer struct {

    mu      sync.RWMutex
    dead    int32
    Rf      *raftcore.Raft
    applyCh chan *pb.ApplyMsg
    lastApplied int
    stm         StateMachine
    notifyChans map[int]chan *pb.CommandResponse
    stopApplyCh chan interface{}
    pb.UnimplementedRaftServiceServer

}

    
```

有了这个结构之后，我们要如何应用Raft算法库实现图中高可用的kv分布式系统呢？

1.首先我们要构造到每个server的rpc客户端； 
2.然后，构造applyCh通道，以及构造日志存储结构； 
3.之后，调用MakeRaft构造我们的Raft算法库核心结构； 
4.最后，启动Apply Goruntine，从通道中监听在经过Raft算法库之后返回的消息。 

```
func MakeKvServer(nodeId int) *KvServer {

clientEnds := []*raftcore.RaftClientEnd{}

for id, addr := range PeersMap {

    newEnd := raftcore.MakeRaftClientEnd(addr, uint64(id))

    clientEnds = append(clientEnds, newEnd)

}

newApplyCh := make(chan *pb.ApplyMsg)

logDbEng, err := storage_eng.MakeLevelDBKvStore("./data/kv_server" + "/node_" + strconv.Itoa(nodeId))

if err != nil {

    raftcore.PrintDebugLog("boot storage engine err!")

    panic(err)

}

// 构造 Raft 结构，传入 clientEnds，当前节点 id, 日志存储的 db, apply 通道，心跳超时时间，和选举超时时间

// 由于是测试，为了方便观察选举的日志，我们设置的时间是 1s 和 3s, 你可以设置的更短

newRf := raftcore.MakeRaft(clientEnds, nodeId, logDbEng, newApplyCh, 1000, 3000)

kvSvr := &KvServer{Rf: newRf, applyCh: newApplyCh, dead: 0, lastApplied: 0, stm: NewMemKV(), notifyChans: make(map[int]chan *pb.CommandResponse)}

kvSvr.stopApplyCh = make(chan interface{})

// 启动 apply Goruntine
go kvSvr.ApplingToStm(kvSvr.stopApplyCh)

return kvSvr
}
```

客户端命令到来之后，最开始调用的是DoCommand函数，我们来看看这个函数做了哪些工作：

首先，Docommand函数调用Marshal序列化了我们的CommandResponse到reqBytes的字节数组中，然后调用Raft库的Propose接口，把提案提交到我们的算法库中。Raft算法中只有Leader可以处理提案。如果节点不是Leader我们会直接返回给客户端ErrCodeWrongLeader的错误码。之后就是从getNotifyChan拿到当前日志id对应的apply通知通道。只有这条日志通知到了，下面select才会继续往下走，拿到值放到cmdResp.Value中，当然如果操作超过了ErrCodeExecTimeout时间也会生成错误码，响应客户端执行超超时。

```
func (s *KvServer) DoCommand(ctx context.Context, req *pb.CommandRequest) (*pb.CommandResponse, error) {

raftcore.PrintDebugLog(fmt.Sprintf("do cmd %s", req.String()))

cmdResp := &pb.CommandResponse{}

if req != nil {

    reqBytes, err := json.Marshal(req)

    if err != nil {

        return nil, err

    }

    idx, _, isLeader := s.Rf.Propose(reqBytes)

    if !isLeader {

        cmdResp.ErrCode = common.ErrCodeWrongLeader

        return cmdResp, nil

    }


    s.mu.Lock()

    ch := s.getNotifyChan(idx)

    s.mu.Unlock()

    select {

    case res := <-ch:

        cmdResp.Value = res.Value

    case <-time.After(ExecCmdTimeout):

        cmdResp.ErrCode = common.ErrCodeExecTimeout

        cmdResp.Value = "exec cmd timeout"

    }
    go func() {

        s.mu.Lock()

        delete(s.notifyChans, idx)

        s.mu.Unlock()

    }()

}

return cmdResp, nil

}
```

最后我们来看看Apply Goruntine干的事情：

它等待s.applyCh通道中apply消息的到来。这个applyCh我们在Raft库中提到过，它用来通知应用层日志已经提交，应用层可以把日志应用到状态机了。当applyCh中appliedMsg到来之后，我们更新了KvServer的lastApplied号，然后根据客户端的操作类型对我们的状态机做不同的操作，做完之后把响应放到notifyChan中，也就是DoCommand等待的那个通道，至此整个请求处理的流程已经结束。

```
func (s *KvServer) ApplingToStm(done <-chan interface{}) {

            for !s.IsKilled() {

                select {

                case <-done:

                    return

                case appliedMsg := <-s.applyCh:

                    req := &pb.CommandRequest{}

                    if err := json.Unmarshal(appliedMsg.Command, req); err != nil {

                        raftcore.PrintDebugLog("Unmarshal CommandRequest err")

                        continue

                    }

                    s.lastApplied = int(appliedMsg.CommandIndex)

                    

                    var value string

                    switch req.OpType {

                    case pb.OpType_OpPut:

                        s.stm.Put(req.Key, req.Value)

                    case pb.OpType_OpAppend:

                        s.stm.Append(req.Key, req.Value)

                    case pb.OpType_OpGet:

                        value, _ = s.stm.Get(req.Key)

                    }

                    

                    cmdResp := &pb.CommandResponse{}

                    cmdResp.Value = value

                    ch := s.getNotifyChan(int(appliedMsg.CommandIndex))

                    ch <- cmdResp

                }

            }

        }

```

### 客户端实现介绍

客户端实现就比较简单了，主要是构造Get和Put的CommandRequest调用DoCommand发送到服务端，逻辑实现在cmd/kvcli/kvcli.go里面。

我们总结一下：

客户端请求到来之后， KvServer首先会调用Propose提交日志到Raft中算法库。Raft算法库经过共识之后提交这条日志，并通知applyCh，KvServer会在Apply Goruntine中将applyCh的消息解码，然后将操作应用到自己的状态机中，最后把结果写到通知客户端的notifyChan中，在DoCommand中响应结果给客户端。

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
