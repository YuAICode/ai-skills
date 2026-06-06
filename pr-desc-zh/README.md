# pr-desc-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/pr-desc-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

从 git diff / commits 生成中文 PR 描述(动机、改动点、测试、影响面),reviewer 看得懂、可回溯。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r pr-desc-zh ~/.claude/skills/
```

## 📖 用法

在功能分支上跟 Claude 说**"写个 PR / 生成 PR 描述"**,它会:

1. 跑 `bin/collect.sh [base]` 采集提交、改动文件、diffstat(base 缺省自动探测 `origin/HEAD`→`main`…);
2. 按模板产出**中文 PR 描述**(做了什么 / 动机 / 改动点 / 影响面 / 测试 / 待确认);
3. 你确认后,可选 `gh pr create` 直接开 PR。

也能单独跑采集脚本看素材:

```bash
bash pr-desc-zh/bin/collect.sh           # 自动定 base
bash pr-desc-zh/bin/collect.sh develop   # 指定 base 分支
```

## 🧪 测试

```bash
bash tests/run.sh   # 临时 repo 造分支+提交,验证素材采集正确
```

## 📄 License

[MIT](../LICENSE)
