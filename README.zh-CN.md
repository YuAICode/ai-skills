# ai-skills 🧠

**简体中文** · [English](./README.md)

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/YuAICode/ai-skills?style=social)](https://github.com/YuAICode/ai-skills/stargazers)
[![markdownlint](https://img.shields.io/badge/lint-markdownlint-brightgreen?logo=markdown)](./commit-guard-zh)

归拢自用的 AI skill 与 AI 项目。每个 skill 一个子目录,含 `SKILL.md`,可直接放进 `~/.claude/skills/` 使用。

## 📦 Skills

| Skill | 作用 | 触发 |
| --- | --- | --- |
| [claude-code-zh](./claude-code-zh) | 把 Claude Code 汉化:中文回复 + 命令中文 tooltip(可一键开关) | `汉化 Claude Code` / 见目录 |
| [slack-to-spec](./slack-to-spec) | 把 Slack 频道讨论收敛成「可落地需求」spec 文档(抓决策轨迹 + 隐藏需求) | `/slack-to-spec <频道> [时间范围]` |
| [commit-guard-zh](./commit-guard-zh) | 提交/推送前护栏(密钥扫描 / GORM×MySQL / 主分支保护)+ 中文 commit | `准备提交` / `bash install.sh` 装 git hook |
| [skill-scaffold](./skill-scaffold) | 一键生成新 skill 标准骨架(SKILL.md + 徽章 README + 可选 bin/tests) | `建个新 skill` / `bash bin/new-skill.sh` |
| [pr-desc-zh](./pr-desc-zh) | 从 git diff/commits 生成中文 PR 描述(动机/改动点/测试/影响面) | `写个 PR` / `生成 PR 描述` |
| [source-to-spec](./source-to-spec) | PDF/飞书/会议纪要 → 可落地需求 spec(slack-to-spec 姊妹篇) | `把这份文档整理成需求` |
| [lambda-logs-zh](./lambda-logs-zh) | 拉 Lambda CloudWatch 报错,按频次聚类 + 中文根因摘要 | `看下 xx 的 lambda 报错` |
| [changelog-zh](./changelog-zh) | conventional commits → 中文 CHANGELOG / release notes | `生成 changelog` / `出个更新日志` |
| [doc-sync](./doc-sync) | 找出代码改动后可能过期的文档候选,由 Claude 判断是否需同步 | `检查文档同步` / `代码改了文档要更新吗` |
| [branch-cleaner](./branch-cleaner) | 列出可清理的本地分支(已合并/陈旧),确认后再删 | `清理分支` / `哪些分支可以删` |
| [go-migration-guard](./go-migration-guard) | 启发式查 GORM 模型改动是否可能缺对应迁移 | `检查迁移` / `gorm 模型改了` |
| [sql-explain-zh](./sql-explain-zh) | 解读慢查询 EXPLAIN + 中文优化建议(索引/回表/filesort) | `EXPLAIN 帮我看下` / `SQL 优化` |
| [env-doctor](./env-doctor) | 跑前环境体检:缺失的 .env、对比模板列出未配置/空值 key | `体检环境` / `.env 缺了什么` |
| [test-gen-zh](./test-gen-zh) | 给指定函数/文件生成测试(探测框架),配合 TDD | `帮我生成测试` / `给这个函数写测试` |
| [dep-audit](./dep-audit) | 扫依赖清单报过期/风险依赖,中文升级摘要 | `检查依赖` / `依赖过期了吗` |
| [cron-regex-buddy](./cron-regex-buddy) | 中文解释/生成 cron 表达式与正则,逐字段讲清+示例 | `解释这个 cron` / `帮我写个正则` |
| [skill-doctor](./skill-doctor) | 发布前 lint skill 目录是否符合合集约定 | `检查 skill` / `lint skill` |
| [error-explain-zh](./error-explain-zh) | 粘任意语言报错/堆栈 → 中文根因 + 可操作修复建议 | `帮我看这个报错` / `这个 panic 怎么回事` |
| [standup-zh](./standup-zh) | 从 git 提交生成中文日报/周报 | `写日报` / `写周报` / `今天做了什么` |
| [readme-init](./readme-init) | 扫项目(栈/结构/脚本)自动生成或刷新 README | `帮我生成 README` / `刷新 README` |
| [gitignore-doctor](./gitignore-doctor) | 揪出被追踪/未忽略的垃圾文件,给 .gitignore 建议 | `检查 gitignore` / `帮我清理 gitignore` |
| [license-picker](./license-picker) | 选 + 生成开源 LICENSE(MIT/ISC/BSD/Unlicense 填充,Apache/GPL 指引) | `选个开源协议` / `加个 LICENSE` |
| [conflict-resolver-zh](./conflict-resolver-zh) | 把 merge/rebase 冲突用中文讲清两边意图,引导解决(不自动改) | `帮我看冲突` / `解冲突` |
| [json-yaml-doctor](./json-yaml-doctor) | 校验/格式化/解释 JSON·YAML·TOML,报错给中文定位 | `校验 json` / `yaml 报错` |
| [curl-buddy](./curl-buddy) | 构造/解释 curl 与 HTTP 请求,逐项拆解 + 安全提示 | `解释这条 curl` / `帮我构造请求` |

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
