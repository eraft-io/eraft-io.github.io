### Welcome to eraft.cn!

<img src="https://eraft.oss-cn-beijing.aliyuncs.com/eraft_logo_150_100.png?versionId=CAEQFBiBgMDVrtfV4hciIDA1YzUwYTg5NzU0NjRhMmJhYmE0NjYyNzQyMjc0MzQ1" style="zoom:50%" />

#### GitHub
[https://github.com/eraft-io/eraft](https://github.com/eraft-io/eraft)

## ERaft overview
Based on Etcd-Raft and implemented by C++, Eraft is a high-performance industrial Raft library. The main idea for this project comes from the manuscript of Diego Ongaro's doctoral thesis. At present, this project has been included in [https://raft.github.io](https://raft.github.io). We hope to explore the possibility of optimizing the existing algorithms on the basis of realizing a stable industrial Raft library. 

ERaft supports academic research projects on scaling out Raft to spot instances. One of our main work has been published in IWQoS 2019.

One may refer to @inproceedings{10.1145/3326285.3329046, author = {Xu, Zichen and Stewart, Christopher and Huang, Jiacheng}, title = {Elastic, Geo-Distributed RAFT}, year = {2019}, isbn = {9781450367783}, publisher = {Association for Computing Machinery}, address = {New York, NY, USA}, url = { [https://doi.org/10.1145/3326285.3329046](https://doi.org/10.1145/3326285.3329046) } , doi = {10.1145/3326285.3329046},  booktitle = {Proceedings of the International Symposium on Quality of Service}, articleno = {11}, numpages = {9}, location = {Phoenix, Arizona}, series = {IWQoS '19} }

Another team of the same root is now working on a stable version called BW-Raft, which inherits the implementation from ERaft. One may refer the latest note from the Good Lab, [https://good.ncu.edu.cn](https://good.ncu.edu.cn)


## Architecture

![eraft base](https://eraft.oss-cn-beijing.aliyuncs.com/rockdb_kv.drawio.svg?versionId=CAEQFBiBgMC3xZbX4hciIGRhYmQ3YzJhNmQ5MjRlYTA5MWRjMTZmMGQ2MzdjYWNl)

## Multi-raft base kv system architecture

![multi raft](https://eraft.oss-cn-beijing.aliyuncs.com/Multi-Raft.png?versionId=CAEQFBiBgID_rtfV4hciIDZiOTAwNTVhOGMwZDRlMjZhYmM0YzNkN2ZmZTQ2ZDY1)

## Features

### Leader election

### Log replication

### Membership changes

### Leadership transfer extension

### Raft scale out ~ Multi Raft Support

## Contact Us

[浙ICP备2021027321号](https://beian.miit.gov.cn)
