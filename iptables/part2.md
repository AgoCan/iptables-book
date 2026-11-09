# 第 2 部分 匹配条件篇

规则 = 匹配条件 + 处理动作。前面只用过 `-s` 这一种条件，本部分把「报文长什么样才被匹配」这件事讲完整：从内置的基本条件，到依赖扩展模块的高级条件。

本部分包含：

* [第 4 章 匹配条件之一：基本匹配与端口扩展](04-basic-match.md)：`-s` / `-d` / `-p` / `-i` / `-o`、取反与「与」关系，扩展模块与 `-m`，tcp 模块的连续端口、multiport 的离散端口。
* [第 5 章 常用扩展模块](05-ext-modules.md)：`iprange`、`string`、`time`、`connlimit`、`limit`，以及 `limit` 背后的令牌桶模型。
* [第 6 章 tcp 扩展模块之 --tcp-flags](06-tcp-flags.md)：TCP 标志位、三次握手、`--tcp-flags` 两段式语法与 `--syn` 简写。
* [第 7 章 udp 扩展与 icmp 扩展](07-udp-icmp.md)：UDP 端口匹配，ICMP 的 type / code 与 `--icmp-type`，只禁止别人 ping 自己。

读完本部分，你应该能按 IP、协议、网卡、端口、报文内容、时间、连接数与速率等维度精确描述一条规则。

上一部分：[第 1 部分 基础篇](part1.md) · 下一部分：[第 3 部分 进阶机制篇](part3.md)。
