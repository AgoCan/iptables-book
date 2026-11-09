> 原文：[iptables详解（6）：iptables扩展匹配条件之 '--tcp-flags'](https://www.zsythink.net/archives/1578) · 作者：朱双印（zsythink.net）

# 6. tcp 扩展模块之 `--tcp-flags`

> 阅读本章需要了解 TCP 头部结构与三次握手过程。

`--tcp-flags` 用于匹配 TCP 头部中的标志位，从而按「连接处于哪个阶段」来做访问控制。

## 6.1 三次握手中的标志位

用 Wireshark 跟踪一次 SSH 连接可以看到：

| 阶段 | 标志位情况 |
| --- | --- |
| 第 1 次握手（客户端 -> 服务端 SYN） | 只有 `SYN = 1`，其余标志位为 0 |
| 第 2 次握手（服务端 -> 客户端 SYN+ACK） | `SYN = 1` 且 `ACK = 1`，其余为 0 |
| 第 3 次握手 | `ACK = 1`，其余为 0 |

Wireshark 中会用形如 `[TCP Flags: ··········S·]`、`[·······A··S·]` 的形式展示，为 1 的位显示字母，为 0 的位显示点。

## 6.2 两段式语法

`--tcp-flags` 后面要跟两组标志位列表，用空格分隔：

```text
--tcp-flags <需要检查的标志位列表> <其中必须为 1 的标志位列表>
```

以 `--tcp-flags SYN,ACK,FIN,RST,URG,PSH SYN` 为例：

- 第一部分 `SYN,ACK,FIN,RST,URG,PSH`：要检查 TCP 头中的这 6 个标志位。
- 第二部分 `SYN`：在这 6 位中，只有 SYN 必须为 1，**其余 5 位必须全部为 0**。

这正是三次握手第一次握手的报文特征，因此可用来匹配「新建连接请求」。

## 6.3 匹配第一次与第二次握手

```bash
# 第一次握手（SYN=1，其余为 0）
iptables -t filter -I INPUT  -p tcp -m tcp --dport 22 --tcp-flags SYN,ACK,FIN,RST,URG,PSH SYN -j REJECT

# 第二次握手（SYN=1、ACK=1，其余为 0）
iptables -t filter -I OUTPUT -p tcp -m tcp --sport 22 --tcp-flags SYN,ACK,FIN,RST,URG,PSH SYN,ACK -j REJECT
```

`ALL` 可以代替第一部分的完整列表：

```bash
iptables -t filter -I INPUT  -p tcp -m tcp --dport 22 --tcp-flags ALL SYN -j REJECT
iptables -t filter -I OUTPUT -p tcp -m tcp --sport 22 --tcp-flags ALL SYN,ACK -j REJECT
```

## 6.4 `--syn`：新建连接请求简写

tcp 模块专门提供了 `--syn` 选项，等价于 `--tcp-flags SYN,RST,ACK,FIN SYN`：

```bash
iptables -t filter -I INPUT -p tcp -m tcp --dport 22 --syn -j REJECT
```

它的含义是匹配 TCP 新建连接的请求报文，是配置「只允许本机主动发起连接、拒绝别人主动连我」时的常用条件之一（更通用的做法是 [第 8 章](08-state.md) 的 state 模块）。

## 6.5 tcp 模块常用条件小结

| 条件 | 含义 | 示例 |
| --- | --- | --- |
| `--sport` | 匹配 TCP 源端口，冒号指定连续范围 | `iptables -t filter -I OUTPUT -d 192.168.1.146 -p tcp -m tcp --sport 22 -j REJECT` |
| `--dport` | 匹配 TCP 目标端口 | `iptables -t filter -I INPUT -s 192.168.1.146 -p tcp -m tcp --dport 22:25 -j REJECT` |
| `--tcp-flags` | 匹配 TCP 头标志位 | `iptables -t filter -I INPUT -p tcp -m tcp --dport 22 --tcp-flags ALL SYN -j REJECT` |
| `--syn` | 匹配新建连接请求 | `iptables -t filter -I INPUT -p tcp -m tcp --dport 22 --syn -j REJECT` |

补充示例：

```bash
iptables -t filter -I OUTPUT -d 192.168.1.146 -p tcp -m tcp --sport 22:25 -j REJECT
iptables -t filter -I OUTPUT -d 192.168.1.146 -p tcp -m tcp ! --sport 22 -j ACCEPT
iptables -t filter -I INPUT  -s 192.168.1.146 -p tcp -m tcp --dport :22 -j REJECT
iptables -t filter -I INPUT  -s 192.168.1.146 -p tcp -m tcp --dport 80: -j REJECT
```

下一章：[第 7 章 udp 与 icmp 扩展](07-udp-icmp.md)。
