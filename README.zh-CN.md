<p align="center">
  <img src="./assets/banner.jpg" alt="ai-skills" width="100%">
</p>

# ai-skills 🧠

**简体中文** · [English](./README.md)

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills)
[![CI](https://github.com/YuAICode/ai-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/YuAICode/ai-skills/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/YuAICode/ai-skills?style=social)](https://github.com/YuAICode/ai-skills/stargazers)
[![markdownlint](https://img.shields.io/badge/lint-markdownlint-brightgreen?logo=markdown)](./skills/commit-guard-zh)

**35 个即用、且每个都带测试的 [Claude Code](https://www.claude.com/product/claude-code) skill。** 有逻辑的 skill 都配离线测试,整个仓库由内置的 [`skill-doctor`](./skills/skill-doctor) 自校验——不是没测试的 AI 批量堆砌。中文优先,大部分跨语言跨栈通用。

每个 skill 是一个含 `SKILL.md` 的独立文件夹,丢进 `~/.claude/skills/` 即可被 Claude 识别。

## ✨ 为什么用这个

- **有测试。** 确定性逻辑写成小 bash 脚本 + `tests/run.sh`(离线、零依赖),全仓几百条断言。
- **自校验。** `skill-doctor` 校验每个 skill 的结构,可进 CI。
- **诚实。** 需要外部工具(aws/mysql/markdownlint…)的 skill,工具缺失时优雅降级,绝不搞崩你的工具链。
- **易扩展。** `skill-scaffold` 一条命令生成新 skill 骨架(SKILL.md + README + 徽章 + 测试)。

## 📦 Skills

### 通用(任何技术栈)

| Skill | 作用 | 触发 |
| --- | --- | --- |
| [error-explain-zh](./skills/error-explain-zh) | 粘任意语言报错/堆栈 → 中文根因 + 可操作修复建议 | `帮我看这个报错` / `这个 panic 怎么回事` |
| [commit-guard-zh](./skills/commit-guard-zh) | 提交/推送前护栏(密钥扫描 / GORM×MySQL / 主分支保护)+ 中文 commit | `准备提交` / `bash install.sh` 装 git hook |
| [pr-desc-zh](./skills/pr-desc-zh) | 从 git diff/commits 生成中文 PR 描述(动机/改动点/测试/影响面) | `写个 PR` / `生成 PR 描述` |
| [changelog-zh](./skills/changelog-zh) | conventional commits → 中文 CHANGELOG / release notes | `生成 changelog` / `出个更新日志` |
| [standup-zh](./skills/standup-zh) | 从 git 提交生成中文日报/周报 | `写日报` / `写周报` / `今天做了什么` |
| [readme-init](./skills/readme-init) | 扫项目(栈/结构/脚本)自动生成或刷新 README | `帮我生成 README` / `刷新 README` |
| [gitignore-doctor](./skills/gitignore-doctor) | 揪出被追踪/未忽略的垃圾文件,给 .gitignore 建议 | `检查 gitignore` / `帮我清理 gitignore` |
| [dep-audit](./skills/dep-audit) | 扫依赖清单报过期/风险依赖,中文升级摘要 | `检查依赖` / `依赖过期了吗` |
| [env-doctor](./skills/env-doctor) | 跑前环境体检:缺失的 .env、对比模板列出未配置/空值 key | `体检环境` / `.env 缺了什么` |
| [test-gen-zh](./skills/test-gen-zh) | 给指定函数/文件生成测试(探测框架),配合 TDD | `帮我生成测试` / `给这个函数写测试` |
| [branch-cleaner](./skills/branch-cleaner) | 列出可清理的本地分支(已合并/陈旧),确认后再删 | `清理分支` / `哪些分支可以删` |
| [conflict-resolver-zh](./skills/conflict-resolver-zh) | 把 merge/rebase 冲突用中文讲清两边意图,引导解决(不自动改) | `帮我看冲突` / `解冲突` |
| [license-picker](./skills/license-picker) | 选 + 生成开源 LICENSE(MIT/ISC/BSD/Unlicense 填充,Apache/GPL 指引) | `选个开源协议` / `加个 LICENSE` |
| [json-yaml-doctor](./skills/json-yaml-doctor) | 校验/格式化/解释 JSON·YAML·TOML,报错给中文定位 | `校验 json` / `yaml 报错` |
| [cron-regex-buddy](./skills/cron-regex-buddy) | 中文解释/生成 cron 表达式与正则,逐字段讲清+示例 | `解释这个 cron` / `帮我写个正则` |
| [curl-buddy](./skills/curl-buddy) | 构造/解释 curl 与 HTTP 请求,逐项拆解 + 安全提示 | `解释这条 curl` / `帮我构造请求` |
| [doc-sync](./skills/doc-sync) | 找出代码改动后可能过期的文档候选,由 Claude 判断是否需同步 | `检查文档同步` / `代码改了文档要更新吗` |
| [slack-to-spec](./skills/slack-to-spec) | 把 Slack 频道讨论收敛成「可落地需求」spec 文档(抓决策轨迹 + 隐藏需求) | `/slack-to-spec <频道> [时间范围]` |
| [source-to-spec](./skills/source-to-spec) | PDF/飞书/会议纪要 → 可落地需求 spec(slack-to-spec 姊妹篇) | `把这份文档整理成需求` |

### 元工具(用来造这个合集本身)

| Skill | 作用 | 触发 |
| --- | --- | --- |
| [skill-scaffold](./skills/skill-scaffold) | 一键生成新 skill 标准骨架(SKILL.md + 徽章 README + 可选 bin/tests) | `建个新 skill` / `bash bin/new-skill.sh` |
| [skill-doctor](./skills/skill-doctor) | 发布前 lint skill 目录是否符合合集约定 | `检查 skill` / `lint skill` |

### 栈专属(Go / AWS / MySQL)

| Skill | 作用 | 触发 |
| --- | --- | --- |
| [lambda-logs-zh](./skills/lambda-logs-zh) | 拉 Lambda CloudWatch 报错,按频次聚类 + 中文根因摘要 | `看下 xx 的 lambda 报错` |
| [go-migration-guard](./skills/go-migration-guard) | 启发式查 GORM 模型改动是否可能缺对应迁移 | `检查迁移` / `gorm 模型改了` |
| [sql-explain-zh](./skills/sql-explain-zh) | 解读慢查询 EXPLAIN + 中文优化建议(索引/回表/filesort) | `EXPLAIN 帮我看下` / `SQL 优化` |
| [claude-code-zh](./skills/claude-code-zh) | 把 Claude Code 汉化:中文回复 + 命令中文 tooltip(可一键开关) | `汉化 Claude Code` / 见目录 |

### 好玩 / 顺手

| Skill | 作用 | 触发 |
| --- | --- | --- |
| [git-undo](./skills/git-undo) | 中文说想撤销啥 git 操作 → 安全恢复命令 + 解释(reflog 优先) | `帮我撤销` / `git 救命` |
| [mermaid-buddy](./skills/mermaid-buddy) | 代码/描述 → mermaid 图(流程/时序/类/ER/状态/甘特),贴文档即用 | `画个流程图` / `转成 mermaid` |
| [commit-roast](./skills/commit-roast) | 读 git 提交历史用中文幽默吐槽,善意有梗、可分享 | `吐槽我的提交` / `损一损 git log` |
| [port-killer](./skills/port-killer) | 找出占端口的进程 + 给 kill 命令(默认只查不杀) | `8080 被占了` / `谁在用这个端口` |
| [naming-buddy](./skills/naming-buddy) | 命名困难症救星:逻辑+语言 → 3-5 个候选名 + 中英理由 + 坏味道诊断 | `帮我起个名字` / `给这函数命名` |
| [tldr-this](./skills/tldr-this) | 把超长文件/PR/文档/文本压成中文 TL;DR + 关键点 | `太长了帮我总结` / `tldr` |
| [dockerfile-doctor](./skills/dockerfile-doctor) | 扫 Dockerfile 体积/安全/缓存/最佳实践问题,给中文修法 | `检查我的 Dockerfile` |
| [mock-data-gen](./skills/mock-data-gen) | 按表结构/struct/JSON 生成假数据/种子数据(JSON/SQL/CSV/NDJSON) | `帮我造测试数据` / `生成假数据` |
| [code-haiku](./skills/code-haiku) | 把函数/代码片段/diff 写成俳句或打油诗,抓住代码神韵 | `给这段代码写首诗` / `写成俳句` |
| [git-blame-story](./skills/git-blame-story) | 把一个文件的修改史讲成有起承转合的中文故事 | `讲讲这个文件的故事` |

## 🚀 安装

### 方式 A —— 作为 Claude Code 插件(推荐)

一次装整套,skill 变成 `/ai-skills:<名字>`:

```text
/plugin marketplace add YuAICode/ai-skills
/plugin install ai-skills@ai-skills
```

### 方式 B —— 单独拷某个 skill

先把仓库拉下来:

```bash
git clone https://github.com/YuAICode/ai-skills.git
cd ai-skills
```

### slack-to-spec(纯 skill,拷目录即可)

把整个子目录放进 Claude Code 的 skills 目录,**重启后**对话里说 `/slack-to-spec` 即可触发:

```bash
cp -r skills/slack-to-spec ~/.claude/skills/
```

> 项目级安装(只在某个项目里生效):拷到该项目的 `.claude/skills/` 而不是 `~/.claude/skills/`。
> 依赖:需要已接入 Slack MCP(`slack_read_channel` 等工具)。

### claude-code-zh(带安装脚本)

进子目录跑安装脚本——它会配好中文回复 + tooltip + 开关命令(自动备份、可逆):

```bash
cd skills/claude-code-zh
bash install.sh
```

装完**重启 Claude Code** 生效。卸载 `bash uninstall.sh`。细节(开关命令 `tooltip on|off`、自定义)见 [claude-code-zh/README](./skills/claude-code-zh)。

### 验证

重启 Claude Code 后,在对话里输入 `/` 看 skill 是否出现在列表;或直接 `ls ~/.claude/skills/` 确认目录已就位。

> 依赖:`bash` + `python3`(claude-code-zh 的脚本用 python3 安全改 `settings.json`)。Claude Code 适配 v2.1.113+。

## 📄 License

[MIT](./LICENSE)
