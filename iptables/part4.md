# 第 4 部分 动作与实战篇

本部分把 iptables 从「保护本机」扩展到「保护整个网络」，并补齐剩余的处理动作，尤其是 NAT 相关的四类动作。

本部分包含：

* [第 11 章 把 iptables 当网络防火墙](11-network-firewall.md)：开启核心转发、规则写在 FORWARD 链、请求与响应的双向性、用 state 模块优化。
* [第 12 章 动作总结之一：REJECT 与 LOG](12-reject-log.md)：`--reject-with` 可选提示，LOG 只记录不处理、`--log-level` 与 `--log-prefix`、单独存放 iptables 日志。
* [第 13 章 动作总结之二：SNAT、DNAT、MASQUERADE、REDIRECT](13-nat-actions.md)：NAT 与 NAPT 场景、四个动作所在的链与选项、共享公网 IP 与发布内网服务。

> 网络防火墙与 NAT 实验涉及多网卡、网关与路由配置，请先确认网络与路由本身正确，并在测试机上进行。

上一部分：[第 3 部分 进阶机制篇](part3.md) · 下一部分：[第 5 部分 总结篇](part5.md)。
