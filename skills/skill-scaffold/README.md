# skill-scaffold 🏗️

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/skill-scaffold)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

一键生成新 Claude Code skill 的标准骨架(SKILL.md + 带徽章的 README + 可选 bin/tests/hooks),并从 git remote 自动填好徽章 URL。

## 🚀 用法

在合集仓库根目录跑:

```bash
bash skill-scaffold/bin/new-skill.sh <name> "<中文描述>" [--bin] [--hooks] [--dir <收纳目录>]
```

- `<name>`:kebab-case(小写 + 连字符)
- `<中文描述>`:进 SKILL.md frontmatter 的 `description`,要含触发词
- `--bin`:额外生成 `bin/` + `tests/run.sh`(确定性脚本类 skill 用)
- `--hooks`:额外生成 `hooks/`(git hook 类),并隐含 `--bin`
- `--dir`:收纳目录,默认当前目录

示例:

```bash
bash skill-scaffold/bin/new-skill.sh pr-desc-zh "从 diff 生成中文 PR 描述。" --bin
```

生成后脚本会打印一行**顶层 README 索引表**该加的 markdown,贴过去即可。

## 🧪 测试

```bash
bash tests/run.sh   # 临时 repo 里跑生成器,断言产物 + 徽章解析 + 防御
```

## ⚙️ 徽章自动解析

读 `git remote get-url origin`,SSH/HTTPS 都支持,解析出 `ORG/REPO` 填进徽章(`-`→`--`、`/`→`%2F` 已转义)。解析不到则用占位符。

## 📄 License

[MIT](../../LICENSE)
