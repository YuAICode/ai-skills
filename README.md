# ai-skills 🧠

归拢自用的 AI skill 与 AI 项目。每个 skill 一个子目录,含 `SKILL.md`,可直接放进 `~/.claude/skills/` 使用。

## 📦 Skills

| Skill | 作用 | 触发 |
| --- | --- | --- |
| [claude-code-zh](./claude-code-zh) | 把 Claude Code 汉化:中文回复 + 命令中文 tooltip(可一键开关) | `汉化 Claude Code` / 见目录 |
| [slack-to-spec](./slack-to-spec) | 把 Slack 频道讨论收敛成「可落地需求」spec 文档(抓决策轨迹 + 隐藏需求) | `/slack-to-spec <频道> [时间范围]` |

## 🚀 使用

每个子目录就是一个独立 skill。两种用法:

**A. 当 Claude Code skill** —— 把子目录拷进 skills 目录:
```bash
git clone https://github.com/YuAICode/ai-skills.git
cp -r ai-skills/slack-to-spec ~/.claude/skills/
# claude-code-zh 另带安装脚本,见其目录 README
```

**B. 带安装脚本的(如 claude-code-zh)** —— 进子目录跑 `install.sh`,详见各自 README。

## 📄 License

[MIT](./LICENSE)
