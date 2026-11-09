> 原文：[iptables详解（10）：iptables自定义链](https://www.zsythink.net/archives/1625) · 作者：朱双印（zsythink.net）

# 10. 自定义链

## 10.1 为什么需要自定义链

如果 INPUT 链里堆了 200 条规则，有针对 httpd 的、sshd 的、私网 IP 的、公网 IP 的，想改一条 web 相关规则就得从头翻一遍，很难维护。

自定义链相当于**规则分组**：把所有针对 80 端口的入站规则放进 `IN_WEB`，把 sshd 出站规则放进 `OUT_SSH`，以后想改哪类规则就去找对应的链。Kubernetes、Docker 生成的 iptables 规则中也大量使用自定义链。

## 10.2 创建自定义链 `-N`

```bash
iptables -t filter -N IN_WEB
```

- 省略 `-t` 时默认在 filter 表中创建。
- 创建后用 `iptables -nvL` 可以看到该链，括号里显示 `(0 references)` —— **引用计数为 0**，表示还没有被任何默认链引用。此时链中的规则不会匹配到任何报文。

## 10.3 在自定义链中写规则

操作方式与默认链完全一致：

```bash
iptables -t filter -I IN_WEB -s 192.168.1.139 -j REJECT
iptables -t filter -I IN_WEB -p tcp --dport 80 -j ACCEPT
```

## 10.4 引用自定义链 `-j`

自定义链必须被默认链引用才生效：

```bash
iptables -t filter -I INPUT -p tcp --dport 80 -j IN_WEB
```

含义：访问本机 80 端口的 TCP 报文，交给 `IN_WEB` 链中的规则处理。此时 `IN_WEB` 的引用计数变为 1。

这也解释了为什么 target 不能简单等同于「动作」：**target 可以是一个动作，也可以是一条自定义链**。自定义链还可以再引用其他自定义链。

> 默认链的匹配范围通常更大，匹配到后再进入自定义链做更细的判断。自定义链中的规则走完仍没有匹配时，会返回调用它的链，继续向下匹配后续规则（`RETURN` 可显式提前返回）。

## 10.5 重命名 `-E`

```bash
iptables -E IN_WEB WEB
```

重命名后，引用处显示的名称会自动更新。

## 10.6 删除 `-X` 的两个条件

```bash
iptables -X WEB
```

删除自定义链必须同时满足：

1. **引用计数为 0**：没有任何链再引用它。否则报错 `Too many links`，需先删除引用规则。
2. **链中没有任何规则**：否则报错 `Directory not empty`，需先用 `-F WEB` 清空。

```bash
iptables -t filter -D INPUT -p tcp --dport 80 -j WEB   # 删除引用规则
iptables -t filter -F WEB                             # 清空自定义链
iptables -X WEB                                       # 删除自定义链
```

## 10.7 本章速查

| 操作 | 命令 |
| --- | --- |
| 创建 | `iptables -t filter -N IN_WEB` |
| 引用 | `iptables -t filter -I INPUT -p tcp --dport 80 -j IN_WEB` |
| 重命名 | `iptables -E IN_WEB WEB` |
| 清空 | `iptables -t filter -F WEB` |
| 删除 | `iptables -X WEB`（需引用计数为 0 且链为空） |

下一章：[第 11 章 网络防火墙](11-network-firewall.md)。
