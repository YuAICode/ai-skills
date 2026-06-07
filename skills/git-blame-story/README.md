# git-blame-story

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/git-blame-story)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

把一个文件的修改史讲成故事——谁、何时、为何改了它。当用户说「讲讲这个文件的故事 / git-blame-story / 这个文件经历了什么 / 追溯文件历史」时触发。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r git-blame-story ~/.claude/skills/
```

## 用法

### 第一步:采集文件历史素材

在目标 git 仓库目录下运行:

```bash
# 分析指定文件
bash <skill>/bin/collect.sh src/auth/login.ts

# 可以是相对路径或绝对路径
bash <skill>/bin/collect.sh ./lib/utils.go
```

输出五段:

- `META` — 文件路径、仓库名、采集时间
- `COMMITS` — 该文件所有提交:hash、作者、日期、subject(含重命名追踪)
- `CONTRIBUTORS` — 贡献者排行(提交数降序)
- `TIMELINE` — 首次提交与最近提交信息
- `CHURN` — 近期改动趋势(最近 5 次提交的增删行数)

### 第二步:Claude 把历史讲成故事

Claude 读取素材,按 SKILL.md 里的叙事框架,把提交历史演绎为有起承转合的中文故事。

## 运行测试

```bash
bash tests/run.sh
```

## License

[MIT](../../LICENSE)
