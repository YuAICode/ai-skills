# port-killer

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/port-killer)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

找出占用某端口的进程,列出 PID / 命令 / 用户并给出 kill 命令;默认只查不杀,加 `--kill --yes` 才真杀。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r port-killer ~/.claude/skills/
```

## 📖 用法

跟 Claude 说**"8080 端口被占了"**或**"帮我杀掉占 3000 端口的进程"**,它会先跑查询脚本展示结果,等你确认后才执行 kill。

也能直接跑脚本:

```bash
# 只查(默认):打印进程信息 + 建议的 kill 命令,不真杀
bash port-killer/bin/whoport.sh 8080

# 查并杀(SIGTERM):打印进程后执行 kill
bash port-killer/bin/whoport.sh 8080 --kill --yes
```

### 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 找到占用进程(只查时也是 0) |
| 1 | 端口空闲 / 参数错误 / lsof 不存在 |

### 环境变量

| 变量 | 说明 |
|------|------|
| `LSOF` | 覆盖 lsof 二进制路径(测试/自定义) |

## 🧪 测试

```bash
bash port-killer/tests/run.sh
```

测试覆盖:端口格式校验、空闲端口提示、lsof 缺失优雅报错、实际监听进程检测(可选,需 python3)。

## ⚙️ 依赖

- `lsof`(macOS 自带;Linux 可 `apt install lsof` / `yum install lsof`)
- Bash 3.2+

## 📄 License

[MIT](../../LICENSE)
