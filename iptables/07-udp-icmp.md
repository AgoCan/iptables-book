> 原文：[iptables详解（7）：iptables扩展之udp扩展与icmp扩展](https://www.zsythink.net/archives/1588) · 作者：朱双印（zsythink.net）

# 7. udp 扩展与 icmp 扩展

tcp、udp、icmp 是与协议相关的三个常用扩展模块。

## 7.1 udp 扩展

udp 模块只有两个匹配条件：

| 条件 | 含义 |
| --- | --- |
| `--sport` | 匹配 UDP 报文的源端口 |
| `--dport` | 匹配 UDP 报文的目标端口 |

```bash
# 放行 samba 服务的 137 端口
iptables -t filter -I INPUT -p udp -m udp --dport 137 -j ACCEPT

# 连续的 UDP 端口范围 137~157
iptables -t filter -I INPUT -p udp -m udp --dport 137:157 -j ACCEPT
```

- 使用 `-p udp` 时可以省略 `-m udp`（iptables 默认调用与协议同名的模块）。
- 与 tcp 模块一样，`--sport` / `--dport` **只能指定连续范围**；要同时指定多个离散 UDP 端口，需借助 `multiport` 模块：

```bash
iptables -t filter -I INPUT -p udp -m multiport --dports 137,138 -j ACCEPT
```

## 7.2 ICMP 与 type / code

ICMP（Internet Control Message Protocol，互联网控制报文协议）用于探测主机是否可达、网络是否通畅、路由是否可用等。ping 是最典型的应用。

ICMP 报文用 **type（类型）** 与 **code（代码）** 两级分类：

| 常见 type / code | 含义 | 类别 |
| --- | --- | --- |
| `0/0` | echo-reply，ping 回应报文 | 查询类 |
| `8/0` | echo-request，ping 请求报文 | 查询类 |
| `3/1` | 主机不可达 | 错误类 |
| `3/x` | 目标不可达的其他细分（网络、端口等） | 错误类 |

例如：所有「目标不可达」报文 type 都是 3，再靠 code 区分是网络不可达、主机不可达还是端口不可达。

## 7.3 只禁止别人 ping 我，但我能 ping 别人

关键：区分请求（type 8）与回应（type 0）。

```bash
# 禁止所有 icmp 报文进入本机：既 ping 不通别人，别人也 ping 不通我
iptables -t filter -I INPUT -p icmp -j REJECT

# 只拒绝 ping 请求（type 8），回应报文 type 0 不受影响
iptables -t filter -I INPUT  -p icmp -m icmp --icmp-type 8/0 -j REJECT
iptables -t filter -I INPUT  -p icmp --icmp-type 8 -j REJECT

# 等价的另一侧写法：拒绝本机发出 ping 回应
iptables -t filter -I OUTPUT -p icmp -m icmp --icmp-type 0/0 -j REJECT
iptables -t filter -I OUTPUT -p icmp --icmp-type 0 -j REJECT
```

- type 8 下只有 code 0 一种，所以 `8/0` 可简写为 `8`。
- 也可以用描述名称，名称中的空格要替换为连字符：

```bash
iptables -t filter -I INPUT -p icmp --icmp-type "echo-request" -j REJECT
```

- 因为 `-p icmp` 与模块同名，`-m icmp` 通常可以省略。

> 易错点：本机 ping 别人时，对方回来的 echo-reply 仍然要走 INPUT 链。如果规则写成 `-p icmp -j DROP` 而不区分 type，本机也收不到回应，表现为「自己也 ping 不通别人」。

## 7.4 本章速查

| 模块 | 条件 | 示例 |
| --- | --- | --- |
| udp | `--sport`、`--dport` | `iptables -t filter -I INPUT -p udp --dport 137:157 -j ACCEPT` |
| icmp | `--icmp-type` | `iptables -t filter -I INPUT -p icmp --icmp-type 8/0 -j REJECT` |

下一章：[第 8 章 state 扩展](08-state.md)。
