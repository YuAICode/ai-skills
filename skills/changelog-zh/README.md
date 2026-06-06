# changelog-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/changelog-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

从 conventional commits 生成中文 CHANGELOG / release notes——按类型归类、面向读者润色,可 prepend 到 CHANGELOG.md。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r changelog-zh ~/.claude/skills/
```

## 📖 用法

跟 Claude 说**"生成 changelog / 出个更新日志"**,它会:

1. 跑 `bin/collect-commits.sh` 按 conventional 类型归类提交(feat/fix/…/other);
2. 确认版本号 + 日期;
3. 润色成中文小节(✨新功能 / 🐛修复 / ⚠️破坏性变更置顶…),prepend 到 `CHANGELOG.md`。

单独跑归类脚本:

```bash
bash changelog-zh/bin/collect-commits.sh            # 最近 tag → HEAD
bash changelog-zh/bin/collect-commits.sh v1.2.0 HEAD
```

## 🧪 测试

```bash
bash tests/run.sh   # 临时 repo 造各类型提交,验证归类/区间/自动取 tag
```

## 📄 License

[MIT](../../LICENSE)
