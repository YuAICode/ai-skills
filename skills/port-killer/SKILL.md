---
name: port-killer
description: 找出占用某端口的进程,列出 PID/命令/用户并给出 kill 命令;默认只查不杀,加 --kill --yes 才真杀。当用户说「X 端口被占了 / 杀掉占 X 端口的进程 / 谁在用 8080 / port killer」时触发。
---

# port-killer — 端口占用查杀

找出哪个进程在占用指定 TCP 端口,列出 PID / 命令 / 用户,给出杀进程命令——默认只查不杀,杀之前先让用户确认。

## 何时触发

- "8080 端口被占了"
- "谁在用 3000 端口"
- "帮我杀掉占 9000 端口的进程"
- "port killer"
- "kill port X"
- "这个端口被占了,启不起来"

## 工作流

1. **查**:跑 `whoport.sh <端口>`,展示占用该端口的进程信息(PID / 命令 / 用户)。
2. **展示**:把结果呈现给用户,同时给出建议的 kill 命令供参考。
3. **确认**:若用户说"杀掉它",**先复述将要杀的进程**,等用户明确同意。
4. **杀**:用户确认后,跑 `whoport.sh <端口> --kill --yes` 执行 SIGTERM。

> **默认只查,不自动杀。** 杀进程是有副作用的操作,必须显式 `--kill --yes` 且用户已确认。

## 用法

```bash
# 只查(展示占用进程 + 建议命令,不杀)
bash <skill>/bin/whoport.sh 8080

# 查并杀(SIGTERM,需 --yes 二次确认)
bash <skill>/bin/whoport.sh 8080 --kill --yes
```

### 输出示例(只查)

```
端口 8080 被以下进程占用:
  PID    命令           用户
  12345  python3        alice
  12346  uvicorn        alice

建议:kill 12345 12346
顽固进程:kill -9 12345 12346
(本次仅查询,未执行 kill)
```

### 输出示例(加 --kill --yes)

```
将要杀死以下进程(SIGTERM):
  PID    命令           用户
  12345  python3        alice
已执行:kill 12345
```

## 环境变量

| 变量 | 说明 |
|------|------|
| `LSOF` | 覆盖 lsof 二进制路径(默认 `lsof`) |

## 边界

- 只找 TCP LISTEN 状态(不含 UDP、已建立连接)。
- 只发 SIGTERM(不自动 -9);顽固进程需用户手动 `kill -9`。
- 需要 `lsof`;没有时脚本给出 `ss -ltnp` / `netstat` 替代命令提示并 exit 1。
- 端口号须为 1-65535 的整数,否则报错并 exit 1。
- 不修改任何系统配置,只读 lsof 输出 + 发送信号。
