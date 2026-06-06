# commit-roast

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/commit-roast)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

读取 git 提交历史,用中文幽默吐槽——敷衍的提交信息、凌晨提交、巨量改动等。当用户说「吐槽提交 / commit roast / 损一损我的 git log / 评价一下我的提交记录」时触发。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r commit-roast ~/.claude/skills/
```

## 用法

### 第一步:采集素材

```bash
# 默认取最近 30 条、当前仓库所有作者
bash <skill>/bin/collect.sh

# 指定数量
bash <skill>/bin/collect.sh 50

# 指定数量 + 过滤作者(支持邮箱或姓名子串)
bash <skill>/bin/collect.sh 30 "alice@example.com"
```

输出四段:

- `META` — 仓库名、采集时间、参数
- `COMMITS` — 每条提交:hash、日期时间、subject
- `SHORTSTATS` — 每条提交的增删行数(供判断巨量改动)
- `SUMMARY` — 总提交数、总增删行数

### 第二步:Claude 吐槽

Claude 读取素材,按 SKILL.md 里的槽点清单和输出格式,生成中文幽默点评报告。

## 运行测试

```bash
bash tests/run.sh
```

## License

[MIT](../../LICENSE)
