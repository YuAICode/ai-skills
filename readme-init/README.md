# readme-init

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/readme-init)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

扫描项目自动生成或刷新 README(检测技术栈/结构/可运行脚本)。用户说「/readme-init」「帮我生成 README」「项目没有 README,帮我写一个」「刷新/更新 README」时触发。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r readme-init ~/.claude/skills/
```

## 用法

在 Claude Code 中输入触发词,Claude 会自动运行扫描脚本并生成 README:

```
/readme-init              # 扫描当前目录
/readme-init ./my-project # 扫描指定目录
```

也可以直接说:"帮我生成 README"、"刷新一下 README"、"这个项目没有 README,帮我写一个"。

### 单独运行扫描脚本

```bash
bash bin/scan-project.sh [项目目录]
```

输出示例:

```
=== LANGUAGES ===
  Go

=== SCRIPTS ===
  - make build
  - make test

=== ENTRYPOINTS ===
  - main.go

=== STRUCTURE ===
  - cmd/
  - internal/
  - go.mod
  - Makefile
```

## 测试

```bash
bash tests/run.sh
# 结果:24 通过 / 0 失败
```

测试覆盖:Node.js / Go / Python / Flutter / Rust / 空目录 / Makefile 脚本提取 / 噪声目录过滤。

## 许可

[MIT](../LICENSE)
