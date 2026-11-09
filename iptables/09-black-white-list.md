> 原文：[iptables详解（9）：iptables的黑白名单机制](https://www.zsythink.net/archives/1604) · 作者：朱双印（zsythink.net）

# 9. 黑白名单机制

> 实验请在测试机上进行，规则设置不当可能导致远程连接中断。

回顾核心机制：报文经过链时按顺序匹配规则，匹配到就执行动作；**所有规则都没匹配到，就执行链的默认策略**。黑白名单就是由「默认策略 + 规则动作」的组合决定的。

## 9.1 两种机制

| 机制 | 默认策略 | 规则动作 | 效果 |
| --- | --- | --- | --- |
| 黑名单 | ACCEPT | DROP / REJECT | 默认放行所有人，只拒绝规则点名的对象 |
| 白名单 | DROP | ACCEPT | 默认拒绝所有人，只放行规则点名的对象 |

如果默认策略已是 ACCEPT，规则动作还写 ACCEPT 就失去了访问控制的意义（匹配与否都被放行）。

简单说：白名单「把所有人都当坏人，只放行好人」，更安全；黑名单「把所有人都当好人，只拒绝坏人」，更灵活。

## 9.2 白名单的朴素写法与它的坑

```bash
iptables -t filter -I INPUT -p tcp --dport 22 -j ACCEPT   # 放行 ssh
iptables -t filter -I INPUT -p tcp --dport 80 -j ACCEPT   # 放行 web
iptables -t filter -P INPUT DROP                          # 默认拒绝
```

这样确实实现了白名单，但埋了一个大坑：一旦执行 `iptables -F`，filter 表所有规则被清空，而默认策略仍是 DROP —— **所有报文（包括管理员当前的 SSH 连接）都会被拒绝**，人会直接被锁在服务器外面。即使没有误操作，链中暂时没有放行规则时也是同样的结果。

## 9.3 推荐写法：默认 ACCEPT + 链尾 REJECT

```bash
# 1. 默认策略保持 ACCEPT
iptables -t filter -P INPUT ACCEPT

# 2. 前面写放行规则（可结合 state 放行响应报文）
iptables -t filter -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t filter -I INPUT -p tcp --dport 22 -j ACCEPT
iptables -t filter -I INPUT -p tcp --dport 80 -j ACCEPT

# 3. 链尾兜底：拒绝所有其他请求
iptables -t filter -A INPUT -j REJECT
```

- 符合放行条件的报文被前面的 ACCEPT 规则匹配；不符合的落到最后一条 REJECT 规则，效果等同白名单。
- 即使误执行 `iptables -F`，默认策略仍是 ACCEPT，管理员还能连上主机修复。

> 这也是 [第 14 章](14-best-practices.md) 总结的常用套路之一：白名单不要把链的默认策略设为 DROP。

## 9.4 关于 REJECT 与 DROP 的选择

链尾兜底用 REJECT 时，客户端会立刻收到拒绝提示；用 DROP 则客户端需要等待超时。行为差异见 [第 3 章](03-manage-rules.md) 与 [第 12 章](12-reject-log.md)。

## 9.5 本章速查

```bash
# 黑名单：默认放行，点名拒绝
iptables -P INPUT ACCEPT
iptables -I INPUT -s 192.168.1.146 -j DROP

# 白名单（推荐）：默认放行，放行规则在前，链尾兜底拒绝
iptables -P INPUT ACCEPT
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -j REJECT
```

下一章：[第 10 章 自定义链](10-user-chain.md)。
