# source-to-spec

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/source-to-spec)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

把 PDF / 飞书文档 / 会议纪要 / 长文本收敛成「可落地需求」spec——抓决策轨迹 + 隐藏需求,能直接喂开发。[slack-to-spec](../slack-to-spec) 的姊妹篇(来源换成文档)。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r source-to-spec ~/.claude/skills/
```

## 📖 用法

跟 Claude 说**"把这份文档/纪要/PDF 整理成需求"**,或:

```
/source-to-spec <文件路径或粘贴内容>
```

它会读源(PDF/飞书 doc/纪要/文本)→ 抽取需求点、决策(含被推翻方案)、待定问题 → 按固定模板产出 `<topic>-spec.md`,并列出"读不到、需人补"的缺口。

> 飞书文档需已接入飞书 MCP;扫描件/加密 PDF 读不到时会**如实标缺口、不臆造**。

## 🔗 与 slack-to-spec 的关系

共用同一套 spec 模板与硬规则(决策日志含撤销轨迹、划开工红线)。来源是 **Slack 频道**用 slack-to-spec;是**文档/纪要**用本 skill。

## 📄 License

[MIT](../LICENSE)
