> 原文：[iptables详解（11）：iptables之网络防火墙](https://www.zsythink.net/archives/1663) · 作者：朱双印（zsythink.net）

# 11. 把 iptables 当网络防火墙

前面的例子中 iptables 都是「主机防火墙」，只防护本机。要当「网络防火墙」，它必须位于网络入口，负责**过滤并转发**内外网之间的报文。

## 11.1 规则写在 FORWARD 链

- 有过滤能力的链只有 INPUT、OUTPUT、FORWARD。
- 需要转发的报文不经过 INPUT / OUTPUT，只经过 FORWARD。

所以作为网络防火墙时，规则只能定义在 **filter 表的 FORWARD 链**中。

## 11.2 开启核心转发

Linux 默认不转发报文。查看当前状态（`0` 未开启，`1` 已开启）：

```bash
cat /proc/sys/net/ipv4/ip_forward
```

临时开启（立即生效，重启网络后失效，二选一）：

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1
```

永久生效：在 `/etc/sysctl.conf`（CentOS 7 为 `/usr/lib/sysctl.d/00-system.conf`）中设置：

```text
net.ipv4.ip_forward = 1
```

## 11.3 实验拓扑

原文用 3 台虚拟机模拟：

| 主机 | 角色 | 地址 |
| --- | --- | --- |
| A | 外部网络主机 | 192.168.1.147 |
| B | iptables 网络防火墙（双网卡） | 内网 10.1.0.3 / 外网 192.168.1.146 |
| C | 内部网络主机 | 10.1.0.1（内网网段 10.1.0.0/16） |

- B 的两块网卡分别连接外网（桥接）与内网（仅主机模式）。
- C 的网关指向 B 的内网 IP `10.1.0.3`；A 访问 10.1 网段的网关指向 B 的外网 IP `192.168.1.146`。
- 测试前清空 A、C 自身的 iptables 规则，避免主机防火墙干扰。

> 一个有意思的现象：没开核心转发时，A 能 ping 通 B 的内网 IP `10.1.0.3`，却 ping 不通 `10.1.0.1`。因为前者是 B 自己的地址，B 直接回应；后者需要 B 转发给 C，而转发功能尚未开启。

## 11.4 必须考虑「双向性」

用白名单机制，先在 FORWARD 链尾添加默认拒绝，再逐条放行：

```bash
iptables -A FORWARD -j REJECT
iptables -I FORWARD -s 10.1.0.0/16 -p tcp --dport 80 -j ACCEPT
```

此时内网主机 C 访问外网 A 的 web 服务**仍然不通**：请求报文能出去，但外部的响应报文无法被转发回来。必须再放行响应方向：

```bash
iptables -I FORWARD -d 10.1.0.0/16 -p tcp --sport 80 -j ACCEPT
```

也就是说，作为网络防火墙配置规则时，往往一个目标需要**两条规则**（请求方向 + 响应方向），要同时考虑源地址、目标地址、源端口、目标端口。

完整示例（允许内网访问外网的 web 与 sshd）：

```bash
iptables -A FORWARD -j REJECT
iptables -I FORWARD -s 10.1.0.0/16 -p tcp --dport 80 -j ACCEPT
iptables -I FORWARD -d 10.1.0.0/16 -p tcp --sport 80 -j ACCEPT
iptables -I FORWARD -s 10.1.0.0/16 -p tcp --dport 22 -j ACCEPT
iptables -I FORWARD -d 10.1.0.0/16 -p tcp --sport 22 -j ACCEPT
```

## 11.5 用 state 模块优化

有了 [第 8 章](08-state.md) 的连接追踪，所有响应报文可以用一条规则统一放行，只需关心请求方向：

```bash
iptables -A FORWARD -j REJECT
iptables -I FORWARD -s 10.1.0.0/16 -p tcp --dport 80 -j ACCEPT
iptables -I FORWARD -s 10.1.0.0/16 -p tcp --dport 22 -j ACCEPT
iptables -I FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
```

后续新增服务时，只要再加一条请求方向的放行规则即可，不必再为每个服务写响应规则。

## 11.6 注意点

1. 测试网络防火墙的前提是**网络与路由本身已正确配置**（网关、路由条目、网卡等）。
2. 出问题时先排查 A、C 上的主机防火墙规则，以及 B 上的核心转发是否开启。
3. 文中只放行了「内网访问外网」；要让外网访问内网服务，还需额外放行「外网到内网」的请求规则（或配合 DNAT，见 [第 13 章](13-nat-actions.md)）。

下一章：[第 12 章 动作总结之一](12-reject-log.md)。
