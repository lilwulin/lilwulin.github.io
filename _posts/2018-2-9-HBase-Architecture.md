---
layout: post
title: HBase的内部存储及架构
---

HBase是[Google Bigtable](https://research.google.com/archive/bigtable-osdi06.pdf)的一个开源实现。它的出现为业界提供了一种高可用、可扩展的数据存储解决方案。在这里，我们一起探索一下HBase的**内部数据结构**，**底层存储结构**，以及**整体架构**，包括它是怎样用到了我们上篇博文学习到的**Log-Structured Merge-Tree**。最后，我们总结一下HBase的优缺点，然后再给一些这篇文章引用的阅读文章，以让大家进行更深度的阅读，加深印象。

## 内部数据结构 - 日志结构合并树
要明白HBase的存储和架构，我们首先要看一下HBase底层所依赖的最基础的数据结构之一——日志结构合并树。这个数据结构我们已经在[这篇博文](({{ site.baseurl }}/LSM-Tree))中提到过了，


## 存储结构

## 整体架构