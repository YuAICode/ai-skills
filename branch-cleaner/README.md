# branch-cleaner

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/branch-cleaner)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

扫描本地 git 分支,找出已合并或长期陈旧的候选分支,展示给用户确认后再删——脚本本身只读,绝不删分支。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r branch-cleaner ~/.claude/skills/
```

## 用法

跟 Claude 说**"清理分支 / 哪些分支可以删 / 整理 git 分支"**,它会:

1. 跑 `bin/list-branches.sh` 列出两组候选:
   - `MERGED:` 已合并进 main/master 的本地分支
   - `STALE:` 最后提交早于 N 天(默认 60)的本地分支
2. 逐条/批量展示候选,征得用户同意。
3. 用户确认后执行 `git branch -d`(合并的)或 `git branch -D`(陈旧未合并的,需额外确认)。

单独跑列表脚本:

```bash
# 缺省:保护 main master + 当前分支,陈旧 = 60 天
bash branch-cleaner/bin/list-branches.sh

# 额外保护 develop release,陈旧判定 30 天
bash branch-cleaner/bin/list-branches.sh "develop release" 30

# 或用环境变量
BRANCH_PROTECT_EXTRA="develop" STALE_DAYS=30 bash branch-cleaner/bin/list-branches.sh
```

示例输出:

```
MERGED: (已合并进 main 的本地分支,可用 git branch -d 删除)
  feature/login-fix                         2026-05-20
  feature/old-api                           2026-04-10

STALE: (最后提交早于 60 天的本地分支,强删需 git branch -D)
  experiment/prototype                      2026-03-01

保护分支(不会列入候选):main master feature/current
```

## 测试

```bash
bash branch-cleaner/tests/run.sh
# 临时 repo 造 main + 已合并 + 未合并 + 陈旧分支,全离线,13 项断言
```

## License

[MIT](../LICENSE)
