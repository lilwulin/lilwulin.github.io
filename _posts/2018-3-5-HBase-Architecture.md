---
layout: post
title: HBase的内部存储及架构
---

HBase是[Google Bigtable](https://research.google.com/archive/bigtable-osdi06.pdf)的一个开源实现。它的出现为业界提供了一种高可用、可扩展的数据存储解决方案。在这里，我们一起探索一下HBase的**内部数据结构**，**底层存储结构**，以及**整体架构**，包括它是怎样用到了我们上篇博文学习到的**Log-Structured Merge-Tree**。最后，我们总结一下HBase的优缺点，然后再给一些这篇文章引用的阅读文章，以让大家进行更深度的阅读，加深印象。

## 内部数据结构 - 日志结构合并树(LSM Tree)
要明白HBase的存储和架构，我们首先要看一下HBase底层所依赖的最基础的数据结构之一: 日志结构合并树。这个数据结构的优点和原理我们已经在[这篇博文]({{ site.baseurl }}/LSM-Tree)中提到过了，所以这里就不再赘述。我们这里重点关注一下HBase对这个数据结构的实现。

HBase的日志结构合并树由三个部分组成：**HLog**（一个预写入式日志Write-ahead log），**MemStore**（存在于内存中的数据结构），还有**HFile**（硬盘上的文件）。我们还没有介绍HBase的RegionServer，因此，我们这里先简单地将一个HBase节点叫做服务器。当服务器想要进行一个写操作（增删改）的时候，它会先将操作append到HLog上，以防数据丢失。在操作条目写入硬盘之后，这条写操作对应的数据（我们简单地把它看做是一对Key-Value值）会被写入到MemStore中。我们在这里不会讨论MemStore的技术细节，它是一个类似于Ordered Map的数据结构，内部使用了[Skip List](https://en.wikipedia.org/wiki/Skip_list)来达到复杂度为Log(N)的查询速度。随着写操作的不断增多，MemStore也会不停地增长。在增长到一定程度时，MemStore里面的内容会被flush到硬盘上，形成一个HFile。HFile里面保存了之前MemStore中排序好了的Key-Value对。在数据都被保存到硬盘上之后，我们就可以销毁旧的HLog，然后创建新的HLog来迎接新的写操作，这个过程就叫做**rolling**。这个写操作的过程我们可以总结如下图：

![]({{ site.baseurl }}/images/LSM-write-path.png)
*Figure 1: HBase LSM Tree write path*

值得注意的是，由于LSM Tree的使用，我们不能立即删除一个Key-Value对。所以删除操作其实是在一个键值对上标记一个**tombstone**，这样在之后的**compaction**过程中再被”垃圾回收“掉。我们之后会讲解一下**compaction**的过程。

在之前的博文我们也提到了，由于键值对可能同时存在于内存以及硬盘的多个HFile中，服务器在查找键值对的时候要先从最新的部分一直查找到最旧的部分，也就是先从内存中查找，再从新到旧遍历硬盘上的HFile查找。由于随着HFile的不断增多，查找的过程会越来越慢，所以服务器需要定期地对多个HFile进行compaction，来减少HFile的查找数量。在HBase中，有两种compaction。一种是**minor compaction**，它每次只会将两个或多个小的HFile合并成一个大的HFile。另外一种是**major comapction**，它会将所有的HFile都合并成一个大文件。一般来说，major compaction比较耗时，所以一般不会在生产环境中让HBase自动运行。我们需要记住的一点是，compaction其实就是对不同IO操作的取舍。如果没有compaction，那我们就牺牲了读操作的性能，换得了最高的写性能。如果我们compaction进行的太频繁，就会对网络和硬盘造成压力。除了compaction之外，HBase也提供了很多类似于索引和Bloom Filter之类的功能来提升读操作性能，这些上一篇博文都提到过，你也可以参考[这篇博文](http://blog.cloudera.com/blog/2012/06/hbase-io-hfile-input-output/)，所以在这里我们也不再赘述了。


## 存储结构

## 整体架构