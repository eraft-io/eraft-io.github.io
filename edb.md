### 架构概述

![https://github.com/eraft-io/eraft-io.github.io/raw/master/figures/E-DB.png](https://github.com/eraft-io/eraft-io.github.io/raw/master/figures/E-DB.png)

### 架构组件
#### E-META
主要存储一些集群 meta 数据，这个模块本身是一个只有一个 region 的 e-store，里面存储了当前集群的 region 信息，每个 store 节点的信息。每次 E-DB 接收到数据写入请求后会先访问 E-META 去找到数据所在的 store 节点，以及 peer 地址，然后再连接这个地址写数据进去。

#### E-DB
这个模块是无状态的，它直接接收来自用户的请求包。并进行 redis 协议解析，同时通过 key 去 E-META 节点找对应的存储节点，将 Redis 不同类型的数据按一定的编码格式写到 E-STORE 节点、或者从节点中读出数据。

#### E-STORE
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

```

message RequestHeader {
    // cluster_id is the ID of the cluster which be sent to.
    uint64 cluster_id = 1;
}

message ResponseHeader {
    // cluster_id is the ID of the cluster which sent the response.
    uint64 cluster_id = 1;
    Error error = 2;
}

enum ErrorType {
    OK = 0;
    UNKNOWN = 1;
    NOT_BOOTSTRAPPED = 2;
    STORE_TOMBSTONE = 3;
    ALREADY_BOOTSTRAPPED = 4;
    INCOMPATIBLE_VERSION = 5;
    REGION_NOT_FOUND = 6;
}

message Error {
    ErrorType type = 1;
    string message = 2;
}

//////////////////////////////////////////////////////////////////////////////////////////


//
// 获取 META 集群所有节点地址，标出 leader 地址。
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

//////////////////////////////////////////////////////////////////////////////////////////

message Store {
    uint64 id = 1;
    // Address to handle client requests (kv, cop, etc.)
    string address = 2;
    StoreState state = 3;
}

message GetAllStoresRequest {
    RequestHeader header = 1;
    // Do NOT return tombstone stores if set to true.
    bool exclude_tombstone_stores = 2;
}

message GetAllStoresResponse {
    ResponseHeader header = 1;

    repeated metapb.Store stores = 2;
}

// 
// 获取集群中所有 store 节点。
//
rpc GetAllStores(GetAllStoresRequest) returns (GetAllStoresResponse) {}

//////////////////////////////////////////////////////////////////////////////////////////

message GetStoreRequest {
    RequestHeader header = 1;

    uint64 store_id = 2;
}

message GetStoreResponse {
    ResponseHeader header = 1;

    metapb.Store store = 2;
    StoreStats stats = 3;
}

//
// 获取 Store 的详细信息，包括状态和机器状态信息，传入 store_id 返回 store 信息。
//
rpc GetStore(GetStoreRequest) returns (GetStoreResponse) {}

//////////////////////////////////////////////////////////////////////////////////////////

message PutStoreRequest {
    RequestHeader header = 1;

    metapb.Store store = 2;
}

message PutStoreResponse {
    ResponseHeader header = 1;
}

//
// store 节点启动注册自己信息接口
//
rpc PutStore(PutStoreRequest) returns (PutStoreResponse) {}

//////////////////////////////////////////////////////////////////////////////////////////

message Peer {      
    uint64 id = 1;
    uint64 store_id = 2;
    string addr = 3;
}

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

//////////////////////////////////////////////////////////////////////////////////////////

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

### E-DB 支持命令列表

- get
- set
- scan


### 重要流程设计

#### 启动流程

#### 切主流程

#### 分裂扩容流程

#### 图数据

[https://github.com/eraft-io/RedisGraph](https://github.com/eraft-io/RedisGraph)
