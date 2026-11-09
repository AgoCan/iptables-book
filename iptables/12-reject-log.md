> 原文：[iptables详解（12）：iptables动作总结之一](https://www.zsythink.net/archives/1684) · 作者：朱双印（zsythink.net）

# 12. 动作总结之一：REJECT 与 LOG

动作和匹配条件一样有「基础」与「扩展」之分：ACCEPT、DROP 是基础动作，REJECT 属于扩展动作。扩展动作可以直接使用，不需要像扩展匹配条件那样显式 `-m` 指定模块。

动作也可以有自己的选项，写在 `-j 动作` 之后。

## 12.1 REJECT 与 `--reject-with`

`--reject-with` 用于设置拒绝时给对方返回的提示信息。可用值：

```text
icmp-net-unreachable      网络不可达
icmp-host-unreachable     主机不可达
icmp-port-unreachable     端口不可达
icmp-proto-unreachable    协议不可达
icmp-net-prohibited       网络被禁止
icmp-host-prohibited      主机被禁止
icmp-admin-prohibited     管理员禁止
```

**不指定时默认值为 `icmp-port-unreachable`**（端口不可达），这就是为什么默认 REJECT 时 ping 会提示「目标端口不可达」。

```bash
# 默认提示：端口不可达
iptables -I INPUT -s 192.168.1.98 -j REJECT

# 改为提示：主机不可达
iptables -I INPUT -s 192.168.1.98 -j REJECT --reject-with icmp-host-unreachable
```

## 12.2 LOG：只记录，不处理

LOG 把匹配到的报文信息记录到日志，但**不决定报文是被接受还是被拒绝**——它属于「非终止 target」，记录后报文会继续匹配后面的规则。要真正处理报文，必须在 LOG 规则之后另写具体规则。

```bash
# 记录发往 22 端口的 tcp 报文，随后继续由后续规则处理
iptables -I INPUT -p tcp --dport 22 -j LOG
```

> 上例匹配条件过于宽泛，会刷出大量日志，仅作演示。生产环境使用 LOG 时应把匹配条件写得尽量精确，减少冗余日志、提高日志可用性。

日志默认写入 `/var/log/messages`。想把 iptables 日志单独存放，可在 `/etc/rsyslog.conf`（或 `/etc/syslog.conf`）中加入：

```text
kern.warning /var/log/iptables.log
```

然后重启日志服务：

```bash
service rsyslog restart
```

## 12.3 LOG 的常用选项

| 选项 | 含义 |
| --- | --- |
| `--log-level` | 指定日志级别：`emerg`、`alert`、`crit`、`error`、`warning`、`notice`、`info`、`debug` |
| `--log-prefix` | 给日志加「标签」，便于过滤分析，**值不能超过 29 个字符** |

```bash
# 记录主动连接 22 端口的报文，并打标签
iptables -I INPUT -p tcp --dport 22 --syn \
  -j LOG --log-level warning --log-prefix "want-in-from-port-22"
```

日志中可以看到源 IP、目标 IP、源端口、目标端口、流入网卡及 MAC 地址等信息。若想「既记录又拒绝」，需要写两条匹配条件相同的规则：

```bash
iptables -I INPUT -p tcp --dport 22 -j LOG --log-prefix "ssh-deny"
iptables -I INPUT -p tcp --dport 22 -j REJECT
```

## 12.4 本章速查

| 需求 | 命令 |
| --- | --- |
| 拒绝并指定提示 | `iptables -I INPUT -j REJECT --reject-with icmp-host-unreachable` |
| 记录日志 | `iptables -I INPUT -p tcp --dport 22 -j LOG` |
| 记录并加标签 | `iptables -I INPUT -j LOG --log-prefix "want-in-from-port-22"` |
| 记录且拒绝 | LOG 规则 + 相同匹配条件的 DROP / REJECT 规则 |

> 已学动作：ACCEPT、DROP、REJECT、LOG；下一章补齐 SNAT、DNAT、MASQUERADE、REDIRECT。

下一章：[第 13 章 动作总结之二](13-nat-actions.md)。
