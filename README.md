# ai-skills 🧠

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/YuAICode/ai-skills?style=social)](https://github.com/YuAICode/ai-skills/stargazers)

归拢自用的 AI skill 与 AI 项目。每个 skill 一个子目录,含 `SKILL.md`,可直接放进 `~/.claude/skills/` 使用。

## 📦 Skills

| Skill | 作用 | 触发 |
| --- | --- | --- |
| [claude-code-zh](./claude-code-zh) | 把 Claude Code 汉化:中文回复 + 命令中文 tooltip(可一键开关) | `汉化 Claude Code` / 见目录 |
| [slack-to-spec](./slack-to-spec) | 把 Slack 频道讨论收敛成「可落地需求」spec 文档(抓决策轨迹 + 隐藏需求) | `/slack-to-spec <频道> [时间范围]` |
| [commit-guard-zh](./commit-guard-zh) | 提交/推送前护栏(密钥扫描 / GORM×MySQL / 主分支保护)+ 中文 commit | `准备提交` / `bash install.sh` 装 git hook |

## 🚀 安装

先把仓库拉下来:

```bash
git clone https://github.com/YuAICode/ai-skills.git
cd ai-skills
```

### slack-to-spec(纯 skill,拷目录即可)

把整个子目录放进 Claude Code 的 skills 目录,**重启后**对话里说 `/slack-to-spec` 即可触发:

```bash
cp -r slack-to-spec ~/.claude/skills/
```

> 项目级安装(只在某个项目里生效):拷到该项目的 `.claude/skills/` 而不是 `~/.claude/skills/`。
> 依赖:需要已接入 Slack MCP(`slack_read_channel` 等工具)。

### claude-code-zh(带安装脚本)

进子目录跑安装脚本——它会配好中文回复 + tooltip + 开关命令(自动备份、可逆):

```bash
cd claude-code-zh
bash install.sh
```

装完**重启 Claude Code** 生效。卸载 `bash uninstall.sh`。细节(开关命令 `tooltip on|off`、自定义)见 [claude-code-zh/README](./claude-code-zh)。

### 验证

重启 Claude Code 后,在对话里输入 `/` 看 skill 是否出现在列表;或直接 `ls ~/.claude/skills/` 确认目录已就位。

> 依赖:`bash` + `python3`(claude-code-zh 的脚本用 python3 安全改 `settings.json`)。Claude Code 适配 v2.1.113+。

## 📄 License

[MIT](./LICENSE)
