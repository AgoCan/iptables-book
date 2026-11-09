> 原文：[iptables详解（1）：iptables概念](https://www.zsythink.net/archives/1199) · 作者：朱双印（zsythink.net）

# 1. iptables 概念

在动手写规则之前，先把「防火墙、netfilter、表、链、规则」这几个概念的关系理清楚，后面的命令才不会变成死记硬背。

## 1.1 防火墙的分类

| 划分角度 | 类型 | 说明 |
| --- | --- | --- |
| 逻辑 | 主机防火墙 | 针对单个主机进行防护 |
| 逻辑 | 网络防火墙 | 处于网络入口或边缘，防护背后的整个局域网 |
| 物理 | 硬件防火墙 | 部分功能在硬件级别实现，性能高、成本高 |
| 物理 | 软件防火墙 | 处理逻辑运行在通用硬件上，性能低、成本低 |

主机防火墙与网络防火墙并不冲突，可以理解为「网络防火墙主外，主机防火墙主内」。iptables 既能当主机防火墙，也能当网络防火墙（见 [第 11 章](11-network-firewall.md)）。

## 1.2 iptables 与 netfilter

**iptables 并不是真正的防火墙**，它只是一个位于用户空间的命令行工具（客户端代理）。真正执行过滤的是内核空间的安全框架 **netfilter**。我们通过 iptables 把安全设定写入 netfilter 对应的规则表中。

netfilter 提供三类能力：

- 网络地址转换（NAT）
- 数据包内容修改
- 数据包过滤（防火墙功能）

因此即便有 `service iptables start` 这样的命令，iptables 也没有守护进程，严格来说不是「服务」，而是内核提供的功能。

## 1.3 规则：匹配条件 + 处理动作

规则（rules）是管理员预定义的条件：如果报文头符合这些条件，就按指定动作处理这个报文。常见的匹配信息包括源地址、目标地址、传输协议、服务类型（端口）等；常见动作是 ACCEPT、REJECT、DROP。

一个便于理解的比喻：链是「关卡」，匹配条件是「器宇轩昂」，动作是「放行」。配置防火墙的主要工作，就是添加、修改、删除这些规则。

报文在链上按顺序匹配规则，一旦匹配到就执行对应动作（LOG 等非终止动作除外），后续规则不再生效；若所有规则都没匹配到，则执行链的**默认策略**。

## 1.4 五条链：报文经过的「关卡」

因为 TCP/IP 协议栈属于内核，报文进出主机都必须经过内核中的钩子点。iptables 把这些钩子点称为「链」：

| 链 | 作用位置 |
| --- | --- |
| PREROUTING | 路由决策之前 |
| INPUT | 发往本机某进程的报文 |
| FORWARD | 由本机转发的报文 |
| OUTPUT | 由本机进程发出的报文 |
| POSTROUTING | 报文离开本机之前的最后一个关卡 |

常见场景的报文流向：

```text
到本机某进程：      PREROUTING --> INPUT
由本机转发：        PREROUTING --> FORWARD --> POSTROUTING
由本机进程发出：    OUTPUT --> POSTROUTING
```

> 之所以叫「链」，是因为每个关卡上可以挂很多条规则，规则串成一条链，报文依次匹配。

## 1.5 四张表：按功能给规则分类

把实现相同功能的规则集合称为「表」，iptables 预定义了 4 张表：

| 表 | 功能 | 内核模块 |
| --- | --- | --- |
| filter | 过滤功能，防火墙的核心 | `iptable_filter` |
| nat | 网络地址转换 | `iptable_nat` |
| mangle | 拆解报文、修改并重新封装 | `iptable_mangle` |
| raw | 关闭 nat 表上启用的连接追踪机制 | `iptable_raw` |

自定义的所有规则，都落在这 4 张表中。

## 1.6 表与链的对应关系

**从链看表（每条链上能存在哪些表的规则）：**

| 链 | 可用表 |
| --- | --- |
| PREROUTING | raw、mangle、nat |
| INPUT | mangle、filter（CentOS 7 中还有 nat，CentOS 6 没有） |
| FORWARD | mangle、filter |
| OUTPUT | raw、mangle、nat、filter |
| POSTROUTING | mangle、nat |

**从表看链（每张表的规则能被哪些链使用）：**

| 表 | 可用链 |
| --- | --- |
| raw | PREROUTING、OUTPUT |
| mangle | PREROUTING、INPUT、FORWARD、OUTPUT、POSTROUTING |
| nat | PREROUTING、OUTPUT、POSTROUTING（CentOS 7 中还有 INPUT） |
| filter | INPUT、FORWARD、OUTPUT |

**表之间的优先级（同一条链上）：**

```text
raw --> mangle --> nat --> filter
```

只有 OUTPUT 链同时拥有这 4 张表的规则。实际写规则时以「表」作为操作入口，用 `-t` 指定，省略时默认操作 filter 表。

另外，可以在某张表中创建**自定义链**，它不能直接使用，必须被默认链以「动作」的方式引用才会生效（详见 [第 10 章](10-user-chain.md)）。

## 1.7 匹配条件与处理动作

**匹配条件**

- 基本匹配条件：源地址（Source IP）、目标地址（Destination IP），可直接使用。
- 扩展匹配条件：源端口、目标端口等，以模块形式存在于 netfilter 中，使用时需要依赖对应的扩展模块（`-m`）。

**常用处理动作（target）**

| 动作 | 含义 |
| --- | --- |
| ACCEPT | 允许数据包通过 |
| DROP | 直接丢弃，不给任何回应，客户端只能等超时 |
| REJECT | 拒绝并给发送端回应信息，客户端立刻收到拒绝提示 |
| SNAT | 源地址转换，让内网用户共享同一个公网地址上网 |
| MASQUERADE | SNAT 的特殊形式，适用于动态、临时变化的 IP |
| DNAT | 目标地址转换 |
| REDIRECT | 在本机做端口映射 |
| LOG | 在 `/var/log/messages` 记录日志，然后把报文交给下一条规则，不做其他处理 |

> 严格来说 target 既可以是动作，也可以是自定义链。

## 1.8 本章速记

```text
netfilter 是内核里的防火墙框架，iptables 是操作它的命令行工具
规则 = 匹配条件 + 动作
链 = 报文流经的 5 个关卡，表 = 按功能划分的 4 类规则集合
表优先级：raw > mangle > nat > filter
报文到本机 PREROUTING->INPUT，转发 PREROUTING->FORWARD->POSTROUTING，本机发出 OUTPUT->POSTROUTING
```

下一章开始动手，先学习怎样「查」规则：[第 2 章 规则查询](02-list-rules.md)。
