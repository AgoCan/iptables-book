> 原文：[iptables详解（2）：iptables实际操作之规则查询](https://www.zsythink.net/archives/1493) · 作者：朱双印（zsythink.net）

# 2. 规则查询

实际操作 iptables 时以「表」为入口，对规则做「增删改查」。本文先从最简单的「查」开始。

> 实验请在测试机上进行，规则配置不当可能导致远程连接中断。

## 2.1 查看一张表的所有规则

```bash
iptables -t filter -L
iptables -t raw -L
iptables -t mangle -L
iptables -t nat -L
```

- `-t`：指定要操作的表；**省略 `-t` 时默认操作 filter 表**，所以 `iptables -L` 等价于 `iptables -t filter -L`。
- `-L`：list，列出规则。

在 filter 表中可以看到 INPUT、FORWARD、OUTPUT 三条链 —— 拥有「过滤」能力的链只有这三条。想禁止某个 IP 访问本机，只能在 INPUT 链（或 PREROUTING 链）配置，而 PREROUTING 链不存在于 filter 表中，因此过滤规则只能写在 INPUT 链。

只查看指定链：

```bash
iptables -t filter -L INPUT
iptables -nvL INPUT
```

## 2.2 常用查看选项

| 选项 | 含义 |
| --- | --- |
| `-t 表名` | 指定操作的表，省略则为 filter |
| `-L` | 列出规则，可与链名配合 |
| `-v` | verbose，显示更详细的字段，包含计数器 |
| `-n` | 不对 IP / 端口做名称反解，直接显示数字，规则多时效率更高 |
| `--line-numbers` | 显示规则序号；无短选项，可简写为 `--line`，但仍是长选项 |
| `-x` | 显示计数器的精确值，而不是自动换算成 K/M 等可读单位 |

短选项通常合并书写：

```bash
iptables --line -t filter -nvxL
iptables --line -t filter -nvxL INPUT
```

## 2.3 `-v` 输出字段含义

| 字段 | 含义 |
| --- | --- |
| `pkts` | 该规则匹配到的报文个数 |
| `bytes` | 匹配到的报文大小总和 |
| `target` | 规则对应的 target，通常就是「动作」 |
| `prot` | 规则对应的协议 |
| `opt` | 规则对应的选项 |
| `in` | 报文由哪个网卡流入 |
| `out` | 报文将由哪个网卡流出 |
| `source` | 规则对应的源地址（IP 或网段） |
| `destination` | 规则对应的目标地址 |

默认情况下 IP 会被反解成 `anywhere` 之类的名称，加 `-n` 后显示为数字地址。

## 2.4 链后的括号：默认策略与计数器

带 `-v` 时，链名后会出现 `(policy ACCEPT 0 packets, 0 bytes)`：

- `policy`：当前链的**默认策略**，即所有规则都未匹配到时执行的默认动作。默认 ACCEPT 意味着「默认放行，只拒绝规则中明确指出的报文」，也就是黑名单机制（见 [第 9 章](09-black-white-list.md)）。
- `packets` / `bytes`：默认策略匹配到的报文数与总大小，只有使用 `-v` 才显示。

每条链有自己的计数器，链中的每条规则也有自己的计数器（`pkts` / `bytes`）。数值较大时 iptables 会自动换算成更易读的单位，用 `-x` 可查看精确值。

## 2.5 命令小结

| 目的 | 命令 |
| --- | --- |
| 查看表的所有规则 | `iptables -t 表名 -L` |
| 查看指定表的指定链 | `iptables -t 表名 -L 链名` |
| 显示详细信息（含计数器） | `iptables -t 表名 -vL` |
| 不解析名称 | `iptables -t 表名 -nL` |
| 显示规则序号 | `iptables --line-numbers -t 表名 -L` |
| 显示精确计数值 | `iptables -t 表名 -vxL` |
| 常用组合 | `iptables --line -t filter -nvxL INPUT` |

下一章：[第 3 章 规则管理](03-manage-rules.md)。
