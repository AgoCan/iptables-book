# iptables

---

## 关于本册

本册按「iptables 零基础快速入门」系列整理的 iptables 学习笔记，内容来自朱双印博客（zsythink.net）的 [IPtables 分类第 1 页](https://www.zsythink.net/archives/category/%e8%bf%90%e7%bb%b4%e7%9b%b8%e5%85%b3/iptables/) 与 [第 2 页](https://www.zsythink.net/archives/category/%e8%bf%90%e7%bb%b4%e7%9b%b8%e5%85%b3/iptables/page/2) 共 14 篇文章。每章开头均标注了对应的原文链接，便于对照阅读。

文章版权归原作者所有。

## 阅读顺序

| 部分 | 章节 | 你会掌握 |
| --- | --- | --- |
| [第 1 部分 基础篇](iptables/part1.md) | 1 ~ 3 | 四表五链、报文流向、规则的增删改查与保存 |
| [第 2 部分 匹配条件篇](iptables/part2.md) | 4 ~ 7 | 基本 / 扩展匹配条件、常用扩展模块、TCP 标志位、UDP 与 ICMP |
| [第 3 部分 进阶机制篇](iptables/part3.md) | 8 ~ 10 | 连接追踪、黑白名单最佳实践、自定义链 |
| [第 4 部分 动作与实战篇](iptables/part4.md) | 11 ~ 13 | 网络防火墙与 FORWARD 链、REJECT / LOG、NAT 四类动作 |
| [第 5 部分 总结篇](iptables/part5.md) | 14 | 规则顺序、方向性、白名单陷阱等常用套路 |

建议按顺序阅读：前面的概念（表、链、规则、默认策略）是后面所有实验的基础。

## 实验提醒

- 所有 iptables 实验请先在**个人测试机**上进行：规则配置不当会切断 SSH 远程连接。
- 修改规则前先备份：`iptables-save > /etc/sysconfig/iptables.bak`。
- 使用白名单时保持链的默认策略为 `ACCEPT`，在链尾用 `REJECT` 兜底，避免误执行 `iptables -F` 后被锁在服务器外面。
- 修改是临时的，记得用 `service iptables save` 或 `iptables-save` 持久化。

## 环境差异

原文示例主要基于 CentOS 6 / CentOS 7：

- CentOS 7 默认使用 firewalld，需要安装 `iptables-services` 才能使用 `service iptables save`。
- `nat` 表在 CentOS 7 的 INPUT 链中可用，CentOS 6 没有；SNAT 在 CentOS 6 中只能用于 POSTROUTING 链。
- `time` 模块默认按 UTC 时间匹配，使用本地时间需注意时区或 `--kerneltz`。
