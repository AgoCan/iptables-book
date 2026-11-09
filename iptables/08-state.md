> 原文：[iptables详解（8）：iptables扩展模块之state扩展](https://www.zsythink.net/archives/1597) · 作者：朱双印（zsythink.net）

# 8. state 扩展与连接追踪

## 8.1 要解决的问题

假设为了让服务端的响应报文能回来，我们在客户端防火墙上放行了源端口 80、22 的报文。那么问题来了：**别人也可以主动从自己的 80 或 22 端口向我们发起连接**，这些报文同样会命中放行规则。

按 IP 逐个加白名单不现实（要访问的网站太多）；用 `--tcp-flags` 判断第一次握手又只适用于 TCP，UDP 和 ICMP 怎么办？

根本问题是：**怎样区分「回应我们之前发出的报文」和「别人主动发来的报文」**？state 扩展模块就是答案。

## 8.2 连接追踪

state 让 iptables 实现「连接追踪」（conntrack）。这里的「连接」与 TCP 连接不是一回事：在 TCP/IP 中 UDP、ICMP 并没有连接概念，但对 state 模块来说，只要两台机器「你来我往」地通信，就算建立了一个连接，其中每个报文都有状态。

报文状态共 5 种：

| 状态 | 含义 |
| --- | --- |
| `NEW` | 连接中的第一个包，即新连接的第一个包 |
| `ESTABLISHED` | NEW 之后的包，表示连接已建立（双向都见过流量） |
| `RELATED` | 与某个已建立连接「有关系」的报文 |
| `INVALID` | 无法识别或没有任何状态的包，通常主动 DROP |
| `UNTRACKED` | 报文未被追踪，通常表示找不到相关连接 |

**RELATED 的典型例子是 FTP**：FTP 有命令连接和数据连接，数据连接由命令连接衍生而来，因此数据连接中的报文可能就是 RELATED 状态。想要对 FTP 做连接追踪，需要单独加载内核模块 `nf_conntrack_ftp`；可在 `/etc/sysconfig/iptables-config` 中配置自动加载。

## 8.3 用 ESTABLISHED / RELATED 放行响应报文

只要放行 `ESTABLISHED`（更保险可加上 `RELATED`），就能做到「只有回应我们的报文能通过」：

```bash
# 放行已建立连接及相关的响应报文
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# 配合默认拒绝，实现「我能访问别人，别人不能主动访问我」
iptables -P INPUT DROP
```

> 注意：直接把默认策略改成 DROP 有把自己锁在外面的风险，生产环境请用下一节的写法（见 [第 9 章](09-black-white-list.md)）。

更稳妥的写法（见 [第 9 章](09-black-white-list.md)）是保持默认 ACCEPT，把拒绝规则放在链尾：

```bash
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -j REJECT
```

效果：本机主动 ssh / ping 外部主机不受影响，能正常收到响应；外部主机无法主动向本机发起新连接。

> 相比 `--tcp-flags` / `--syn`，state 模块对 TCP、UDP、ICMP 都有效，而且不需要为每个服务单独写「响应报文放行规则」，这也是 [第 11 章](11-network-firewall.md) 优化 FORWARD 链规则的关键。

## 8.4 本章速查

| 目的 | 命令 |
| --- | --- |
| 放行响应报文 | `iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT` |
| 丢弃异常状态报文 | `iptables -I INPUT -m state --state INVALID -j DROP` |
| FTP 连接追踪 | 加载 `nf_conntrack_ftp` 模块，或配置 `/etc/sysconfig/iptables-config` |

下一章：[第 9 章 黑白名单机制](09-black-white-list.md)。
