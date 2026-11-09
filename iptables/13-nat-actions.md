> 原文：[iptables详解（13）：iptables动作总结之二](https://www.zsythink.net/archives/1764) · 作者：朱双印（zsythink.net）

# 13. 动作总结之二：SNAT、DNAT、MASQUERADE、REDIRECT

## 13.1 NAT 与 NAPT

NAT（Network Address Translation，网络地址转换）说白了就是修改报文的 IP 地址，通常集成在路由器、防火墙或独立的 NAT 设备中。同时映射 IP 与端口的实现称为 **NAPT**（Network Address Port Translation）。

**场景 1（SNAT）**：内网 10 台主机访问外网时，网关把报文的**源 IP / 源端口**改为自己的公网 IP / 端口，并维护一张 NAT 表记录映射关系；外部主机回应时，网关再按表把**目标 IP / 目标端口**改回内网主机。这样既隐藏了内网主机 IP，也让多台私网主机共享一个公网 IP 上网。

**场景 2（DNAT）**：公司只有一个公网 IP，内网却有 web、数据库等多台服务器。对外宣称该公网 IP 提供服务，网关收到请求后把**目标 IP / 目标端口**改为对应内网服务器（例如 公网IP:80 -> 主机1:80，公网IP:3306 -> 主机2:3306），回应报文再自动转换回来。

> 一次完整的通信中 SNAT 与 DNAT 都会发生；整个过程叫 SNAT 还是 DNAT，取决于**前半段**用了哪种转换。iptables 会自动维护 NAT 表，因此通常只需配置一侧即可。

**前提**：NAT 主机必须开启核心转发（见 [第 11 章](11-network-firewall.md)）：

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```

## 13.2 四个动作总览

| 动作 | 用途 | 所在表 / 链 | 关键选项 |
| --- | --- | --- | --- |
| SNAT | 固定公网 IP 的源地址转换 | nat 表 POSTROUTING（CentOS 7 还可 INPUT） | `--to-source` |
| DNAT | 通过公网 IP 访问内网服务 | nat 表 PREROUTING / OUTPUT | `--to-destination` |
| MASQUERADE | 公网 IP 动态获取时的「动态 SNAT」 | nat 表 POSTROUTING | 配合 `-o 网卡`，无需指定 IP |
| REDIRECT | 本机端口映射 | nat 表 PREROUTING / OUTPUT | `--to-ports` |

为什么 SNAT 放在 POSTROUTING？因为它是报文离开本机前的最后一道关卡，必须在发出前改完源地址。DNAT 放在 PREROUTING，是因为要在路由决策之前先把目标地址改好，报文才会被转发到内网主机。

## 13.3 SNAT：共享公网 IP 上网

```bash
iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -j SNAT --to-source 公网IP
```

- `-t nat`：地址转换规则写在 nat 表。
- `-s 10.1.0.0/16`：只处理来自内网的报文。
- `--to-source 公网IP`：把源 IP 改成网关的公网 IP。

原文实验：内网 C（10.1.0.1）能 ping 通外网 A 并访问其 web 服务；在 A 上抓包只能看到网关 B 的公网 IP，A 完全感知不到 C 的存在。只配置这一条 SNAT 即可，响应报文的地址还原由 iptables 自动完成。

## 13.4 DNAT：发布内网服务

```bash
# 公网 3389 -> 内网 windows 远程桌面
iptables -t nat -I PREROUTING -d 公网IP -p tcp --dport 3389 -j DNAT --to-destination 10.1.0.6:3389

# 公网 8080 -> 内网 web 服务 80
iptables -t nat -I PREROUTING -d 公网IP -p tcp --dport 8080 -j DNAT --to-destination 10.1.0.1:80
```

`--to-destination` 可同时指定私网 IP 与端口；SNAT 规则配置一条即可，DNAT 规则要按服务逐条配置。

> 原文注：理论上只配置 DNAT 即可，iptables 会自动处理响应报文；但作者的实验中需要同时配置对应的 SNAT 才能正常 DNAT。因此排查时可先只写 DNAT，不通再补 SNAT：
>
> ```bash
> iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -j SNAT --to-source 公网IP
> ```
>
> 是否需要补 SNAT，取决于内网服务器的网关是否指向 NAT 主机、响应报文是否会原路返回。

## 13.5 MASQUERADE：动态 SNAT

拨号上网等场景每次分配的公网 IP 都不同，用 SNAT 就得不断改规则。MASQUERADE 会自动把源地址改为**指定出站网卡上当前可用的 IP**：

```bash
iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -o eth0 -j MASQUERADE
```

它可以理解为动态、自动化的 SNAT。由于需要动态查询网卡地址，开销比 SNAT 大；没有动态 IP 需求时优先用 SNAT。

## 13.6 REDIRECT：本机端口映射

```bash
# 访问本机 80 端口的报文重定向到本机 8080
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080
```

REDIRECT 只能定义在 PREROUTING 或 OUTPUT 链中。

## 13.7 命令小结

```bash
# 前提：开启核心转发
echo 1 > /proc/sys/net/ipv4/ip_forward

# SNAT：共享固定公网 IP
iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -j SNAT --to-source 公网IP

# MASQUERADE：动态公网 IP
iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -o eth0 -j MASQUERADE

# DNAT：发布内网服务
iptables -t nat -I PREROUTING -d 公网IP -p tcp --dport 公网端口 -j DNAT --to-destination 私网IP:端口号
iptables -t nat -I PREROUTING -d 公网IP -p tcp --dport 8080 -j DNAT --to-destination 10.1.0.1:80

# 必要时配合的 SNAT
iptables -t nat -A POSTROUTING -s 10.1.0.0/16 -j SNAT --to-source 公网IP

# REDIRECT：本机端口映射
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080
```

下一章：[第 14 章 常用套路](14-best-practices.md)。
