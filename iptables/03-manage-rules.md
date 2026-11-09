> 原文：[iptables详解（3）：iptables规则管理](https://www.zsythink.net/archives/1517) · 作者：朱双印（zsythink.net）

# 3. 规则管理：增删改与保存

> 本章实验务必在个人测试机上进行。规则设置不当可能把自己锁在服务器外面。

先清空实验环境（此处 `-F INPUT` 清空 filter 表 INPUT 链的规则，默认策略仍为 ACCEPT）：

```bash
iptables -F INPUT
```

## 3.1 增加规则

| 语法 | 含义 |
| --- | --- |
| `iptables -t 表名 -A 链名 匹配条件 -j 动作` | `-A`（append）在链的**尾部**追加规则 |
| `iptables -t 表名 -I 链名 匹配条件 -j 动作` | `-I`（insert）在链的**首部**插入规则 |
| `iptables -t 表名 -I 链名 规则序号 匹配条件 -j 动作` | 在链的指定位置插入规则 |

```bash
# 拒绝来自 192.168.1.146 的所有报文
iptables -t filter -I INPUT -s 192.168.1.146 -j DROP
# 在尾部追加一条放行规则
iptables -A INPUT -s 192.168.1.146 -j ACCEPT
# 在 INPUT 链第 5 条位置插入
iptables -t filter -I INPUT 5 -s 192.168.1.146 -j REJECT
```

- `-s`：source，匹配条件中的源地址。
- `-j`：指定匹配成功后要执行的动作；在 iptables 中动作被称为 target。
- 省略 `-t` 时默认操作 filter 表。

### 规则的顺序非常重要

原文做了一个关键实验：

```text
第 1 条：DROP   来自 146 的报文
第 2 条：ACCEPT 来自 146 的报文   -> 仍然 ping 不通，第 2 条计数器为 0

调整后：
第 1 条：ACCEPT 来自 146 的报文
第 2 条：DROP   来自 146 的报文   -> 可以 ping 通
```

报文一旦被前面的规则匹配并执行动作（ACCEPT / DROP / REJECT），即使后面的规则也能匹配，也没有机会再执行了。所以**针对同一服务，更严格的规则要放前面**；LOG 是例外，它记录后仍继续匹配。

规则被匹配时，用 `iptables -nvL` 可以看到该规则的 `pkts` / `bytes` 计数器增长，这是排查规则是否生效的实用手段。

## 3.2 删除规则

```bash
# 按序号删除
iptables -t filter -D INPUT 3

# 按匹配条件与动作删除（多个选项需与添加时一致）
iptables -t filter -D INPUT -s 192.168.1.146 -j DROP

# 清空指定链的所有规则
iptables -t filter -F INPUT

# 清空指定表的所有链
iptables -t filter -F
```

- `-D`：delete，删除规则。
- `-F`：flush，清空链或表。按条件删除时若存在多条相同规则，只会删除第一条。
- **在没有保存规则前，慎用 `-F`**：清空后默认策略若为 DROP，会立即切断包括 SSH 在内的所有连接（见 [第 9 章](09-black-white-list.md)）。

## 3.3 修改规则

```bash
# 把 INPUT 链第 1 条规则的动作改为 REJECT
iptables -t filter -R INPUT 1 -s 192.168.1.146 -j REJECT
```

**`-R` 有个大坑**：即使指定了规则序号，也必须把原规则的所有匹配条件写全。若省略 `-s 192.168.1.146`，修改后的源地址会自动变成 `0.0.0.0/0`，配合 `-j REJECT` 就是「拒绝所有 IP」，正在 SSH 远程操作的你会被直接踢下线。

因此更稳妥的做法通常是：**先按序号删除，再在原位置插入新规则**。

### DROP 与 REJECT 的区别

| 动作 | 表现 |
| --- | --- |
| DROP | 直接丢弃，不给回应，客户端一直等到超时 |
| REJECT | 拒绝并回应提示信息，客户端立刻看到「目标不可达」 |

## 3.4 修改默认策略

每张表的每条链都有自己的默认策略（默认动作），在报文没有匹配到任何规则时生效：

```bash
iptables -t filter -P FORWARD DROP
iptables -t filter -P INPUT ACCEPT
```

`-P`（policy）只能用于内置链，策略值通常只能是 ACCEPT 或 DROP（不能设为 REJECT）。

## 3.5 保存规则

默认情况下，所有修改都是临时的，重启 iptables 服务或重启主机后丢失。

**CentOS 6：**

```bash
service iptables save          # 规则保存到 /etc/sysconfig/iptables
service iptables restart       # 未保存时可用它把规则恢复到上次保存的状态
```

**CentOS 7** 默认使用 firewalld，需要安装 `iptables-services` 后才能使用上述命令：

```bash
yum install -y iptables-services
systemctl stop firewalld
systemctl disable firewalld
systemctl start iptables
systemctl enable iptables
```

**通用方法（导出 / 载入）：**

```bash
iptables-save > /etc/sysconfig/iptables
iptables-restore < /etc/sysconfig/iptables
```

`iptables-save` 只是把当前规则以「保存格式」输出到屏幕，需要配合重定向写入文件；`iptables-restore` 从文件重载规则，**会覆盖现有未保存的修改**。

## 3.6 命令小结

| 分类 | 语法 / 示例 |
| --- | --- |
| 尾部追加 | `iptables -t filter -A INPUT -s 192.168.1.146 -j DROP` |
| 首部插入 | `iptables -t filter -I INPUT -s 192.168.1.146 -j ACCEPT` |
| 指定位置插入 | `iptables -t filter -I INPUT 5 -s 192.168.1.146 -j REJECT` |
| 设置默认策略 | `iptables -t filter -P FORWARD ACCEPT` |
| 按序号删除 | `iptables -t filter -D INPUT 3` |
| 按条件删除 | `iptables -t filter -D INPUT -s 192.168.1.146 -j DROP` |
| 清空链 / 表 | `iptables -t filter -F INPUT` / `iptables -t filter -F` |
| 修改规则 | `iptables -t filter -R INPUT 3 -s 192.168.1.146 -j ACCEPT`（匹配条件不可省） |
| 保存 / 载入 | `service iptables save` / `iptables-save > /etc/sysconfig/iptables` / `iptables-restore < /etc/sysconfig/iptables` |

下一章：[第 4 章 匹配条件总结之一](04-basic-match.md)。
