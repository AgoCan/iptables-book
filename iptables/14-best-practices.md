> 原文：[iptables详解（14）：iptables小结之常用套路](https://www.zsythink.net/archives/1869) · 作者：朱双印（zsythink.net）

# 14. 常用套路小结

系列前 13 篇中有一些反复出现的注意点，这里集中总结，记住它们能少踩很多坑。

## 14.1 规则的顺序非常重要

报文一旦被前面的规则匹配到，iptables 就会执行对应动作（通常是 ACCEPT 或 REJECT），报文被放行或拒绝后，即使后面的规则也能匹配，也没机会再执行了（**前面规则的动作为 LOG 时除外**）。

因此针对相同服务的规则，**更严格的规则应该放在前面**。

## 14.2 一条规则中的多个匹配条件默认是「与」

报文必须同时满足规则中的所有匹配条件，才算被这条规则匹配。例如 `-s 192.168.1.146 -p tcp --dport 22`，三个条件需同时成立。

## 14.3 在没有顺序要求时，把更容易匹配到的规则放前面

假设一天内有 20000 个请求访问 web 服务、200 个请求访问 sshd。把 web 规则放前面，绝大多数报文第一次匹配就命中；反过来则每次 web 请求都要先白跑一遍 sshd 规则，白白耗费资源。

结论：**不同类别的规则，被匹配次数多、频率高的应放在前面**。

## 14.4 作为网络防火墙时，双向都要考虑

iptables 所在主机作为网络防火墙时，规则写在 FORWARD 链，配置时要同时考虑「从外到内」和「从内到外」两个方向：请求报文放行了，响应报文也要能回来（或用 `-m state --state ESTABLISHED,RELATED -j ACCEPT` 一条规则统一放行响应报文）。

## 14.5 白名单不要靠默认策略 DROP 实现

配置白名单时，通常把链的默认策略保持为 **ACCEPT**，在链的**最后**设置一条 REJECT 规则来实现白名单，而不是把默认策略设为 DROP。

原因：如果默认策略是 DROP，一旦链中的规则被清空（误执行 `iptables -F`、规则被覆盖等），管理员自己的请求也会被 DROP，直接被锁在服务器外面。保持默认 ACCEPT，即使规则被清空，仍有机会连上去修复。

## 14.6 全系列速查

| 主题 | 关键命令 / 结论 | 章节 |
| --- | --- | --- |
| 表链关系 | `raw > mangle > nat > filter`；filter 只有 INPUT/FORWARD/OUTPUT | [1](01-concepts.md) |
| 查询规则 | `iptables --line -t filter -nvxL INPUT` | [2](02-list-rules.md) |
| 增删改 | `-A` 尾部、`-I` 首部、`-D` 删除、`-R` 修改（匹配条件不可省）、`-P` 默认策略 | [3](03-manage-rules.md) |
| 保存规则 | `service iptables save`；`iptables-save > /etc/sysconfig/iptables`；`iptables-restore < ...` | [3](03-manage-rules.md) |
| 基本条件 | `-s` `-d` `-p` `-i` `-o`，支持网段、逗号多值、`!` 取反 | [4](04-basic-match.md) |
| 扩展模块 | `-m` 指定模块；协议同名模块可省略 `-m` | [4](04-basic-match.md) |
| 端口 | `--sport/--dport` 连续范围，`-m multiport --dports` 离散端口 | [4](04-basic-match.md) |
| 常用模块 | `iprange` `string` `time` `connlimit` `limit` | [5](05-ext-modules.md) |
| TCP 标志位 | `--tcp-flags ALL SYN`、`--syn` | [6](06-tcp-flags.md) |
| UDP / ICMP | `--dport`；`--icmp-type 8/0` 请求、`0/0` 回应 | [7](07-udp-icmp.md) |
| 连接追踪 | `-m state --state ESTABLISHED,RELATED -j ACCEPT` | [8](08-state.md) |
| 白名单 | 默认 ACCEPT + 放行规则 + 链尾 `REJECT` | [9](09-black-white-list.md) |
| 自定义链 | `-N` 创建、`-j` 引用、`-E` 重命名、`-X` 删除 | [10](10-user-chain.md) |
| 网络防火墙 | 开启 `ip_forward`，规则写在 `FORWARD` 链，注意双向性 | [11](11-network-firewall.md) |
| REJECT / LOG | `--reject-with`；LOG 只记录不处理，需后续规则 | [12](12-reject-log.md) |
| NAT | `SNAT --to-source`、`DNAT --to-destination`、`MASQUERADE -o`、`REDIRECT --to-ports` | [13](13-nat-actions.md) |

> 实验提醒：iptables 规则配置不当会切断远程连接，所有练习请先在个人测试机上进行，并养成及时保存规则的习惯。
