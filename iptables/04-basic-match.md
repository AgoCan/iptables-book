> 原文：[iptables详解（4）：iptables匹配条件总结之一](https://www.zsythink.net/archives/1544) · 作者：朱双印（zsythink.net）

# 4. 匹配条件之一：基本匹配与端口扩展

> 实验请在测试机上进行，规则设置不当可能导致远程连接中断。

前面只用过 `-s` 这一种匹配条件。本章系统梳理基本匹配条件，并引出「扩展匹配条件」与「扩展模块」的概念。

## 4.1 源地址 `-s`

```bash
# 单个 IP
iptables -t filter -I INPUT -s 192.168.1.146 -j DROP

# 多个 IP，用逗号分隔（逗号两侧不能有空格），一次添加多条规则
iptables -t filter -I INPUT -s 192.168.1.111,192.168.1.118 -j DROP

# 一个网段
iptables -t filter -I INPUT -s 192.168.1.0/24 -j ACCEPT

# 取反
iptables -t filter -I INPUT ! -s 192.168.1.0/24 -j ACCEPT
```

### 关于取反的易错点

`! -s 192.168.1.146 -j ACCEPT` 的含义是「**只要源 IP 不是 146 就接受**」，而不是「源 IP 是 146 就拒绝」。当来自 146 的报文没有匹配到这条规则时，它会继续匹配后面的规则；若后面没有规则，就执行**链的默认策略**。默认策略为 ACCEPT 时，146 仍然能 ping 通；改为 DROP 才会被丢弃。

结论：取反条件要和默认策略一起看，不能孤立理解。

## 4.2 目标地址 `-d`

```bash
iptables -t filter -I OUTPUT -d 192.168.1.111,192.168.1.118 -j DROP
iptables -t filter -I INPUT  -d 192.168.1.0/24 -j ACCEPT
iptables -t filter -I INPUT  ! -d 192.168.1.0/24 -j ACCEPT
```

- 不指定源地址或目标地址时，默认值都是 `0.0.0.0/0`（所有 IP）。
- `-s` 与 `-d` 都支持多 IP、网段、`!` 取反，但**取反与「逗号指定多个 IP」不能同时使用**。

## 4.3 协议类型 `-p`

```bash
iptables -t filter -I INPUT -p tcp -s 192.168.1.146 -j ACCEPT
iptables -t filter -I INPUT ! -p udp -s 192.168.1.146 -j ACCEPT
```

- CentOS 6 支持：`tcp, udp, udplite, icmp, esp, ah, sctp`
- CentOS 7 另支持：`icmpv6, mh`
- 不指定 `-p` 时匹配所有协议，等同于 `-p all`。

## 4.4 网卡接口 `-i` / `-o`

| 选项 | 含义 | 可用链 |
| --- | --- | --- |
| `-i` | 匹配报文从哪个网卡**流入** | PREROUTING、INPUT、FORWARD |
| `-o` | 匹配报文从哪个网卡**流出** | FORWARD、OUTPUT、POSTROUTING |

```bash
iptables -t filter -I INPUT  -p icmp -i eth4 -j DROP
iptables -t filter -I INPUT  -p icmp ! -i eth4 -j DROP
iptables -t filter -I OUTPUT -p icmp -o eth4 -j DROP
iptables -t filter -I OUTPUT -p icmp ! -o eth4 -j DROP
```

FORWARD 链处在「中间」，因此 `-i` 和 `-o` 都可以使用。

## 4.5 多个条件之间是「与」关系

一条规则中写多个匹配条件时，报文必须**同时满足所有条件**才算匹配。例如同时指定 `-s 192.168.1.146` 与 `-d 192.168.1.101`，只有「来自 146 且发往 101」的报文才会命中。

## 4.6 扩展匹配条件与 `-m`

源端口、目标端口属于**扩展匹配条件**：它们不是 iptables 内置的基本条件，而是由扩展模块提供的，使用前需要指定模块。

```bash
# 显式指定 tcp 扩展模块
iptables -t filter -I INPUT -s 192.168.1.146 -p tcp -m tcp --dport 22 -j REJECT

# 省略 -m 也可以
iptables -t filter -I INPUT -s 192.168.1.146 -p tcp --dport 22 -j REJECT
```

规则：当使用扩展匹配条件却没有用 `-m` 指定模块时，iptables **默认调用与 `-p` 协议名同名的模块**。`-p tcp` 隐含 `-m tcp`，`-p udp` 隐含 `-m udp`。若扩展条件所属的模块名与协议名不同（如 `multiport`），则 `-m` 不能省略。

注意 `-p tcp` 与 `-m tcp` 含义不同：前者匹配报文协议，后者指定扩展模块，只是名字恰好相同。

## 4.7 tcp 扩展模块：连续端口

| 条件 | 含义 |
| --- | --- |
| `--sport` | 匹配 TCP 报文的源端口 |
| `--dport` | 匹配 TCP 报文的目标端口 |

```bash
iptables -t filter -I OUTPUT -d 192.168.1.146 -p tcp -m tcp --sport 22 -j REJECT
iptables -t filter -I INPUT  -s 192.168.1.146 -p tcp -m tcp --dport 22:25 -j REJECT
iptables -t filter -I INPUT  -s 192.168.1.146 -p tcp -m tcp --dport :22 -j REJECT   # 0~22
iptables -t filter -I INPUT  -s 192.168.1.146 -p tcp -m tcp --dport 80: -j REJECT   # 80~65535
iptables -t filter -I OUTPUT -d 192.168.1.146 -p tcp -m tcp ! --sport 22 -j ACCEPT
```

扩展条件同样支持 `!` 取反（`! --dport 22` 表示目标端口不是 22）。冒号只能表达**连续**端口范围。

## 4.8 multiport 扩展模块：离散端口

```bash
# 同时指定多个离散目标端口
iptables -t filter -I INPUT -s 192.168.1.146 -p tcp -m multiport --dports 22,36,80 -j REJECT

# 离散端口 + 连续范围混用
iptables -t filter -I INPUT -s 192.168.1.146 -p tcp -m multiport --dports 22,80:88 -j REJECT

# 源端口、取反
iptables -t filter -I INPUT  -s 192.168.1.146 -p tcp -m multiport ! --dports 22,80 -j REJECT
iptables -t filter -I OUTPUT -d 192.168.1.146 -p udp -m multiport --sports 137,138 -j REJECT
```

- `--sports` / `--dports` 属于 multiport 模块，**`-m multiport` 不可省略**，否则 iptables 会误以为调用 `-m tcp` 而报错。
- multiport 只能配合 `-p tcp` 或 `-p udp` 使用。

## 4.9 本章速查

| 条件 | 选项 | 要点 |
| --- | --- | --- |
| 源地址 | `-s` | 多 IP 用逗号、可写网段、可 `!` 取反 |
| 目标地址 | `-d` | 同上；缺省 `0.0.0.0/0` |
| 协议 | `-p` | tcp/udp/icmp 等；缺省等同 `-p all` |
| 流入网卡 | `-i` | 只能用于 PREROUTING / INPUT / FORWARD |
| 流出网卡 | `-o` | 只能用于 FORWARD / OUTPUT / POSTROUTING |
| TCP 端口 | `-m tcp --sport/--dport` | 连续范围用冒号；可省略 `-m tcp` |
| 离散端口 | `-m multiport --sports/--dports` | 必须显式 `-m`，仅 tcp/udp |

下一章：[第 5 章 常用扩展模块](05-ext-modules.md)。
