> 原文：[iptables详解（5）：iptables匹配条件总结之二（常用扩展模块）](https://www.zsythink.net/archives/1564) · 作者：朱双印（zsythink.net）

# 5. 常用扩展模块

`-s` / `-d` 只能指定若干个 IP 或网段，无法表达「一段连续 IP」「报文中包含某字符串」「某个时间段」「限制连接数」「限制报文速率」。这些需求由扩展模块提供。

## 5.1 iprange：连续的 IP 地址范围

| 条件 | 含义 |
| --- | --- |
| `--src-range` | 匹配源地址所在的连续范围 |
| `--dst-range` | 匹配目标地址所在的连续范围 |

```bash
iptables -t filter -I INPUT  -m iprange --src-range 192.168.1.127-192.168.1.146 -j DROP
iptables -t filter -I OUTPUT -m iprange --dst-range 192.168.1.127-192.168.1.146 -j DROP
iptables -t filter -I INPUT  -m iprange ! --src-range 192.168.1.127-192.168.1.146 -j DROP
```

范围起止用横杠连接，条件可用 `!` 取反。

## 5.2 string：匹配报文中的字符串

| 条件 | 含义 |
| --- | --- |
| `--algo` | 指定匹配算法，可选 `bm`、`kmp`，**必填** |
| `--string` | 指定要匹配的字符串 |

```bash
# 报文中包含 OOXX 则拒绝
iptables -t filter -I INPUT -p tcp --sport 80 -m string --algo bm --string "OOXX" -j REJECT
```

典型场景：作为网络防火墙时，阻止含有特定内容的网页响应通过。注意它匹配的是报文内容，HTTPS 等加密流量无法按内容匹配。

## 5.3 time：按时间段匹配

| 条件 | 含义 | 可否取反 |
| --- | --- | --- |
| `--timestart` | 起始时间（如 09:00:00） | 否 |
| `--timestop` | 结束时间（如 18:00:00） | 否 |
| `--weekdays` | 星期几，可写 `1,2,...` 或 `Mon,Tue,...`，多个用逗号 | 是 |
| `--monthdays` | 每月几号，多个用逗号 | 是 |
| `--datestart` | 起始日期 | 否 |
| `--datestop` | 结束日期 | 否 |

```bash
# 每天 9 点到 19 点禁止访问 web
iptables -t filter -I OUTPUT -p tcp --dport 80  -m time --timestart 09:00:00 --timestop 19:00:00 -j REJECT
iptables -t filter -I OUTPUT -p tcp --dport 443 -m time --timestart 09:00:00 --timestop 19:00:00 -j REJECT

# 周六日拒绝
iptables -t filter -I OUTPUT -p tcp --dport 80 -m time --weekdays 6,7 -j REJECT

# 每月 22、23 号拒绝（取反示例）
iptables -t filter -I OUTPUT -p tcp --dport 80 -m time --monthdays 22,23 -j REJECT
iptables -t filter -I OUTPUT -p tcp --dport 80 -m time ! --monthdays 22,23 -j REJECT

# 组合：周六日 9 点到 18 点
iptables -t filter -I OUTPUT -p tcp --dport 80 -m time --timestart 09:00:00 --timestop 18:00:00 --weekdays 6,7 -j REJECT

# 组合：每月第 4 个星期五（多条件是「与」关系）
iptables -t filter -I OUTPUT -p tcp --dport 80 -m time --weekdays 5 --monthdays 22,23,24,25,26,27,28 -j REJECT

# 指定日期范围
iptables -t filter -I OUTPUT -p tcp --dport 80 -m time --datestart 2017-12-24 --datestop 2017-12-27 -j REJECT
```

> 实践提示：time 模块默认按 **UTC** 时间判断，与北京时间相差 8 小时；可使用 `--kerneltz`（旧版为 `--localtz`）让内核时区生效，或在写规则时自行换算。

## 5.4 connlimit：限制每个客户端 IP 的并发连接数

| 条件 | 含义 |
| --- | --- |
| `--connlimit-above N` | 连接数**超过** N 时匹配，默认针对每个客户端 IP |
| `--connlimit-mask N` | 按掩码把「某类网段」视为一个整体来限制 |
| `--connlimit-upto N` | CentOS 7 提供，等价于 `! --connlimit-above N`，不常用 |

```bash
# 每个 IP 最多 2 个 ssh 连接
iptables -I INPUT -p tcp --dport 22 -m connlimit --connlimit-above 2 -j REJECT

# 一个 C 类网段（/24）合计最多 20 个 ssh 连接
iptables -I INPUT -p tcp --dport 22 -m connlimit --connlimit-above 20 --connlimit-mask 24 -j REJECT

# 一个 /27 网段合计最多 10 个 ssh 连接
iptables -I INPUT -p tcp --dport 22 -m connlimit --connlimit-above 10 --connlimit-mask 27 -j REJECT
```

注意：一般**不要对 `--connlimit-above` 取反**。「连接数不超过 2 就放行」并不等价于「超过 2 就拒绝」——超出部分的报文会因没匹配到规则而落到默认策略上，达不到限制效果。

## 5.5 limit：限制报文到达速率（令牌桶）

connlimit 限制「连接数量」，limit 限制「单位时间内的报文数量」。

| 条件 | 含义 |
| --- | --- |
| `--limit` | 生成新令牌的频率，单位可用 `/second`、`/minute`、`/hour`、`/day` |
| `--limit-burst` | 令牌桶容量（初始令牌数），**默认 5** |

**令牌桶模型**：桶里最多放 `--limit-burst` 个令牌，每过一个 `--limit` 指定的时间间隔生成 1 个新令牌，桶满则溢出丢弃。报文必须拿到令牌才能被这条规则匹配，桶空后报文只能靠后续规则或默认策略处理。

这就解释了原文实验中的一个坑：只写一条「每 6 秒放行 1 个 icmp 包」的 ACCEPT 规则，**完全起不到限速作用** —— 没匹配到该规则的包会落到 INPUT 链的默认策略 ACCEPT 上，等于全部放行。必须在后面补一条拒绝规则：

```bash
# 每分钟放行 10 个 icmp 包（每 6 秒 1 个），桶容量 3
iptables -t filter -I INPUT -p icmp -m limit --limit-burst 3 --limit 10/minute -j ACCEPT
# 兜底：没拿到令牌的 icmp 包全部拒绝
iptables -t filter -A INPUT -p icmp -j REJECT
```

开头前几个包不受限制，正是因为令牌桶初始就有 5 个令牌（上例显式设为 3）。

## 5.6 本章速查

| 模块 | 解决问题 | 关键选项 |
| --- | --- | --- |
| `iprange` | 连续 IP 段 | `--src-range`、`--dst-range` |
| `string` | 报文内容过滤 | `--algo`（必填）、`--string` |
| `time` | 时间段控制 | `--timestart`、`--timestop`、`--weekdays`、`--monthdays`、`--datestart`、`--datestop` |
| `connlimit` | 并发连接数 | `--connlimit-above`、`--connlimit-mask` |
| `limit` | 报文速率 | `--limit`、`--limit-burst` |

> 更多选项说明可参考系统手册 `man iptables-extensions`。

下一章：[第 6 章 tcp-flags](06-tcp-flags.md)。
