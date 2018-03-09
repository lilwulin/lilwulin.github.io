---
layout: post
title: HBase的内部存储及架构
---

HBase是[Google Bigtable](https://research.google.com/archive/bigtable-osdi06.pdf)的一个开源实现。它的出现为业界提供了一种高可用、可扩展的数据存储解决方案。在这里，我们一起探索HBase的**内部数据结构**，**底层存储结构**，以及**整体架构**，包括它是怎样用到了我们上篇博文学习到的**Log-Structured Merge-Tree**。最后，我们总结一下HBase的优缺点，给一些这篇文章引用的阅读文章，让大家进行更深度的阅读，加深印象。

## 内部数据结构 - 日志结构合并树(LSM Tree)
要明白HBase的存储和架构，我们首先要理解HBase所依赖的数据结构: 日志结构合并树。这个数据结构的优点和原理我们已经在[这篇博文]({{ site.baseurl }}/LSM-Tree)中提到过，所以这里不再赘述。我们重点关注HBase对这个数据结构的实现。

HBase的日志结构合并树由三个部分组成：**HLog**（一个预写入式日志Write-ahead log），**MemStore**（内存中的数据结构），还有**HFile**（硬盘上的文件）。我们还没有介绍HBase的RegionServer，因此，我们这里先简单地将HBase节点叫做服务器。当服务器想要进行一个写操作（增删改）时，会先将操作append到HLog上，以防数据丢失。在操作条目写入硬盘之后，这条写操作对应的数据（简单地把它看做是一个键值对）会被写入到MemStore中。我们在这里不会讨论MemStore的技术细节，它是一个类似于ordered map的数据结构，内部使用了[skip list](https://en.wikipedia.org/wiki/Skip_list)来达到复杂度为Log(N)的查询速度。随着写操作的不断增多，MemStore也会不停地增长。在增长到一定程度时，MemStore里面的内容会被flush到硬盘上，形成一个HFile。HFile里面的键值对已经排序好了，因此可以进行很快速的查找。在数据都被保存到硬盘上之后，我们就可以销毁旧的HLog，然后创建新的HLog来迎接新的写操作，这个过程就叫做**rolling**。这个写操作的过程我们可以总结如下图：


![]({{ site.baseurl }}/images/LSM-write-path.png)
*Figure 1: HBase LSM Tree write path*


值得注意的是，由于LSM Tree的使用，我们不能立即删除一个键值对。所以删除操作其实是在键值对上标记一个**tombstone**，这样在之后的**compaction**过程中它再被”垃圾回收“掉。我们接下来讲解一下**compaction**的过程。

在之前的博文我们也提到，由于键值对可能同时存在于内存以及硬盘的多个HFile中，服务器在查找键值对的时候要先从最新的部分一直查找到最旧的部分，也就是先从内存中查找，再从新到旧遍历硬盘上的HFile。随着HFile的不断增多，查找的过程会越来越慢，所以服务器需要定期地对多个HFile进行compaction，来减少HFile的查找数量。在HBase中，有两种compaction。一种是**minor compaction**，它每次只会将两个或多个小的HFile合并成一个大的HFile。另外一种是**major comapction**，它会将所有的HFile都合并成一个大文件。一般来说，major compaction比较耗时，所以一般不在生产环境中让HBase自动运行。我们需要记住的一点是，compaction其实就是对不同IO操作的取舍。如果没有compaction，我们就牺牲了读操作的性能，换得了最高的写性能。如果我们compaction进行的太频繁，就会对网络和硬盘造成压力。除了compaction之外，HBase也提供了类似于索引和Bloom Filter之类的功能来提升读操作性能，这些上一篇博文都提到过，你也可以参考[这篇博文](http://blog.cloudera.com/blog/2012/06/hbase-io-hfile-input-output/)，所以在这里我们也不再赘述。


## 底层存储结构
在明白了HBase中最基本的数据结构之后，我们再更深入地了解HBase如何把数据存储在文件中。

一个HBase的表会被水平切分成好几份，每一份都叫做一个**Region**。每一个Region都有一个起始的**row key**和结尾的row key。每一个Region又被分配给了不同的节点，这些节点叫做**Region Server**，一个Region Server可以负责多个Region，但是一个Region只可以被一个Region Server管理。一个Region中会有多个**Store**结构，每个Store对应于不同的**Column Family**。一个Store其实就是一个MemStore和多个HFile的包装。这些结构的关系可以由下图所示。值得注意的是，在HBase的实现中，Region Server被命名为**HRegionServer**，Region被命名为**HRegion**。


![]({{ site.baseurl }}/images/hbase-storage-architecture.png)
*Figure 2: HBase storage architecture*


一个Region在增长到一定程度的时候，会被自动**split**成两半。我们也可以人工地对不同的Region进行split操作，甚至可以提前指定split的点。只要登录HBase的UI管理界面，就可以很容易找到对应的操作。

我们提到了HFile包含着排序好的键值对。但其实HFile被分成了多个小的block，这样使得split，cache，index，压缩还有读操作都更容易。Block用来保存index，元信息，Bloom Filter，还有键值对数据（**data block**）。这里我们只讨论data block。每一个data block都包含着头信息还有一系列的键值对，每一个键值对其实是一个序列化了的KeyValue实例，也就是一个byte数组。它的格式如下图所示：


![]({{ site.baseurl }}/images/hbase-keyvalue-layout.png)
*Figure 3: KeyValue instance layout*


看到这里，你可能会感到奇怪。为什么我们还没有讨论**HDFS（Hadoop Distributed File System**？HBase难道不是运行在HDFS上的吗？实际上，HBase通过自身的一个FileSystem接口来存储文件，所以底层的文件系统可以是本地文件系统，HDFS，甚至可以是AWS的S3。HDFS只是最常用的方案。HDFS也会把文件切分成不同的block，但这与HBase没有任何关系。


## 集群架构
弄懂了底层的存储结构，我们现在可以从整体来看HBase的集群架构。一个HBase的集群由三个重要部分组成：主节点，叫做**HMaster**；从节点，上一节已经提到它叫做**HRegionServer**；还有Zookeeper，一个分布式的协调服务。HRegionServer我们上一节已经有所介绍，我们接下来介绍HMaster和Zookeeper。

一个HMaster节点负责监视HRegionServer的状态，以及分配Region。另外一些管理功能，比如创建，删除以及更新表的操作，都要经由HMaster发起。

Zookeeper可以被视作一个高可用的分布式键值对存储。它可以被运行在一台或者多台机器上，常常被用作分布式系统的配置管理（distributed configuration service），同步（synchronization service），以及名字注册（naming registry）。在HBase的集群中，它被用来维护服务器状态，以及存储META表的地址。我们后面会提到META表。

HRegionServer和HMaster会连接到Zookeeper集群，然后持续地发送心跳信息。HMaster通过Zookeeper来发现可用的HRegionServer，还有检测HRegionServer是否正常运行。HMaster也需要发送心跳信息，这样我们可以运行着两个HMaster节点，如果一个被检测到无法正常运行了，另一个节点就可以切换进去。这些部件的关系可以由下图所示：


![]({{ site.baseurl }}/images/hbase-architecture.png)
*Figure 4: HBase architecture*


HBase会自带一个特殊的表，叫做META表（一些介绍老版本HBase的博客还会提到ROOT表，不过在0.96.0版本后就没有了）。这个META表保存了其他表的名字，起始的row key，Region的ID，还有对应的HRegionServer。

我们现在假设一个客户开始从HBase集群中读一些键值对，客户端的cache为空：
1. 首先它会向Zookeeper集群请求存储着META表的HRegionServer；
2. 得到HRegionServer的地址后，它再从该HRegionServer中的META表读取出包含自己需要的键值对的HRegionServer的地址；
3. 最后，它访问对应的HRegionServer，读取出自己想要的键值对。
这些中间过程的地址都会被客户端cache到，一直重复利用，知道访问失败为止。因此，客户端之后可以不经过Zookeeper，直接向HRegionServer读取自己想要的键值对。写操作也是同样，要记住它会涉及到我们第一节说到的关于LSM Tree写操作的整个过程。这些提到的步骤如下图所示：


![]({{ site.baseurl }}/images/hbase-read-write-path.png)

*Figure 5: HBase read & write path*



## 总结
我们可以总结出HBase的特点：
1. HBase是一个使用了主从架构的分布式数据库
2. 一个HBase的表可以被分配到多台机器中
3. 在一个节点上，HBase利用LSM Tree来进行顺序硬盘操作，提升了写性能
4. 为了不影响读性能，HBase会定期地进行compaction
HBase的优化有很多技巧，比如给row key加盐（salting）使得row key均匀分布，利用split解决Region“过热”，压缩，load balancing，等等。最后提供的延伸阅读提供了很多HBase优化的内容。我们在这里可以很容易地得出HBase的优点，那就是对于传统数据来说很头疼的sharding，对HBase来说是与生俱来的，并且还提供了很多自动的比如compaction，split还有load balancer功能，使得整个集群可以支撑起极其大的数据集。但同时，它的缺点也很明显，对比于传统的数据库，它不支持transaction；极其依赖于row key已经排序好的这个特性，要在其他column建立索引会很痛苦；在数据集较小的时候，HDFS还有网络之间通信的overhead会占到比较大的一个比例。因此我们在选择HBase作为我们的数据存储时，必须对自己的业务心中有数。


## 延伸阅读
1. [An In-Depth Look at the HBase Architecture](https://mapr.com/blog/in-depth-look-hbase-architecture/)
2. [HBase: The Definitive Guide](http://shop.oreilly.com/product/0636920014348.do)
3. [Apache HBase I/O – HFile](http://blog.cloudera.com/blog/2012/06/hbase-io-hfile-input-output/)
4. [Apache HBase Write Path](http://blog.cloudera.com/blog/2012/06/hbase-write-path/)
5. [Apache HBase Region Splitting and Merging](https://hortonworks.com/blog/apache-hbase-region-splitting-and-merging/)




