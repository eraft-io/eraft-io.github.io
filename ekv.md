### 架构概述

![https://github.com/eraft-io/eraft-io.github.io/raw/master/figures/ekv_1.png](https://github.com/eraft-io/eraft-io.github.io/raw/master/figures/ekv_1.png)

### 架构组件
#### E-META
主要存储一些集群 meta 数据，这个模块本身是一个只有一个 region 的 e-store，里面存储了当前集群的 region 信息，每个 store 节点的信息。每次 E-DB 接收到数据写入请求后会先访问 E-META 去找到数据所在的 store 节点，以及 peer 地址，然后再连接这个地址写数据进去。

#### E-KV
这个是具体存储数据的节点，最小部署 3 节点，它们可以组成一个或者多个 Raft Group 对 E-DB 提供高可用的存储服务，同时 E-STORE 会定期的上报 E-META 节点信息，看是否需要扩容分裂，E-STORE 具有自动分裂的能力。

### RPC 设计

**E-STORE**

- RawGet

```

rpc RawGet(kvrpcpb.RawGetRequest) returns (kvrpcpb.RawGetResponse) {}

message RawGetRequest {
    Context context = 1;
    bytes key = 2;
    string cf = 3;
}

message RawGetResponse {
    errorpb.Error region_error = 1;
    string error = 2;
    bytes value = 3;
    // True if the requested key doesn't exist; another error will not be signalled.
    bool not_found = 4;
}

```

- RawPut

```

rpc RawPut(kvrpcpb.RawPutRequest) returns (kvrpcpb.RawPutResponse) {}

message RawPutRequest {
    Context context = 1;
    bytes key = 2;
    bytes value = 3;
    string cf = 4;
    uint64 id = 5;
    uint32 type = 6;
}

message RawPutResponse {
    errorpb.Error region_error = 1;
    string error = 2;
}

```

- RawDelete

```

rpc RawDelete(kvrpcpb.RawDeleteRequest) returns (kvrpcpb.RawDeleteResponse) {}

message RawDeleteRequest {
    Context context = 1;
    bytes key = 2;
    string cf = 3;
}

message RawDeleteResponse {
    errorpb.Error region_error = 1;
    string error = 2;
}

```

- RawScan

```

rpc RawScan(kvrpcpb.RawScanRequest) returns (kvrpcpb.RawScanResponse) {}

message RawScanRequest {
    Context context = 1;
    bytes start_key = 2;
    // The maximum number of values read.
    uint32 limit = 3;
    string cf = 4;

}

message RawScanResponse {
    errorpb.Error region_error = 1;
    // An error which affects the whole scan. Per-key errors are included in kvs.
    string error = 2;
    repeated KvPair kvs = 3;
}

```

- TransferLeader

```

rpc TransferLeader(raft_cmdpb.TransferLeaderRequest) returns (raft_cmdpb.TransferLeaderResponse) {}

message Peer {      
    uint64 id = 1;
    uint64 store_id = 2;
    string addr = 3;
}

message TransferLeaderRequest {
    metapb.Peer peer = 1;
}

message TransferLeaderResponse {}

```

- PeerConfChange

```

rpc PeerConfChange(raft_cmdpb.ChangePeerRequest) returns (raft_cmdpb.ChangePeerResponse) {}

message ChangePeerRequest {
    // This can be only called in internal Raftstore now.
    eraftpb.ConfChangeType change_type = 1;
    metapb.Peer peer = 2;
}

message ChangePeerResponse {
    metapb.Region region = 1;
}

```

**E-META**

- 获取 meta_server 所有节点

```

//
// E-KV 获取 META 集群所有节点地址，标出 leader 地址。
//
rpc GetMembers(GetMembersRequest) returns (GetMembersResponse) {}

message GetMembersRequest {
    RequestHeader header = 1;
}

// E-META 集群的成员列表
message Member {
    // name is the name of the Scheduler member.
    string name = 1;
    // member_id is the unique id of the Scheduler member.
    uint64 member_id = 2;
    repeated string peer_urls = 3;
}

message GetMembersResponse {
    ResponseHeader header = 1;

    repeated Member members = 2;
    Member leader = 3;
}

```

- 用户通过key请求E-meta查找key所在的region

```

message GetRegionRequest {
    RequestHeader header = 1;
    bytes region_key = 2;
}

message GetRegionResponse {
    ResponseHeader header = 1;
    metapb.Region region = 2;
    metapb.Peer leader = 3;
    repeated metapb.Peer slaves = 4;
}

//
// 根据写入的 key 获取 region 成员信息，写 kv 的时候通过这个确认要写入的节点。
//
rpc GetRegion(GetRegionRequest) returns (GetRegionResponse) {}

```

- 每个region的leader上报region信息给E-META

```

rpc RegionHeartbeat(RegionHeartbeatRequest) returns (RegionHeartbeatResponse) {}

message RegionHeartbeatRequest {
    RequestHeader header = 1;
    metapb.Region region = 2; // 要上报的region信息
    // Leader Peer sending the heartbeat.
    metapb.Peer leader = 3;   // region的leader信息
    // Pending peers are the peers that the leader can't consider as
    // working followers.
    repeated metapb.Peer pending_peers = 5;
    // Approximate region size.
    uint64 approximate_size = 10;
}

message RegionHeartbeatResponse {  //只需要ok就可以
    ResponseHeader header = 1;

    // Notice, Scheduleeer only allows handling reported epoch >= current scheduler's.
    // Leader peer reports region status with RegionHeartbeatRequest
    // to scheduler regularly, scheduler will determine whether this region
    // should do ChangePeer or not.
    // E,g, max peer number is 3, region A, first only peer 1 in A.
    // 1. Scheduler region state -> Peers (1), ConfVer (1).
    // 2. Leader peer 1 reports region state to scheduler, scheduler finds the
    // peer number is < 3, so first changes its current region
    // state -> Peers (1, 2), ConfVer (1), and returns ChangePeer Adding 2.
    // 3. Leader does ChangePeer, then reports Peers (1, 2), ConfVer (2),
    // scheduler updates its state -> Peers (1, 2), ConfVer (2).
    // 4. Leader may report old Peers (1), ConfVer (1) to scheduler before ConfChange
    // finished, scheduler stills responses ChangePeer Adding 2, of course, we must
    // guarantee the second ChangePeer can't be applied in TiKV.
    ChangePeer change_peer = 2;
    // Scheduler can return transfer_leader to let TiKV does leader transfer itself.
    TransferLeader transfer_leader = 3;
    // ID of the region
    uint64 region_id = 4;
    metapb.RegionEpoch region_epoch = 5;
    // Leader of the region at the moment of the corresponding request was made.
    metapb.Peer target_peer = 6;
}

```

- 用户请求分裂region

```

message AskSplitRequest {
    RequestHeader header = 1;
    metapb.Region region = 2;
}

message AskSplitResponse {
    ResponseHeader header = 1;
    // We split the region into two, first uses the origin
    // parent region id, and the second uses the new_region_id.
    // We must guarantee that the new_region_id is global unique.
    uint64 new_region_id = 2;
    // The peer ids for the new split region.
    repeated uint64 new_peer_ids = 3;
}

// 触发分裂
rpc AskSplit(AskSplitRequest) returns (AskSplitResponse) {}

```
