# git-undo

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/git-undo)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

撤销 git 操作的安全向导。把用户用中文描述的"出了什么事"，变成**安全的恢复命令 + 解释 + 风险提示**。救命级实用。

## 安装

把本目录拷进 Claude Code 的 skills 目录，重启后即可触发：

```bash
# 全局（所有项目可用）
cp -r git-undo ~/.claude/skills/

# 或 项目级（只在当前项目生效）
cp -r git-undo .claude/skills/
```

**重启 Claude Code** 后即可触发。

## 用法

直接用中文说出遇到了什么问题，触发词之一即可：

- `帮我撤销`
- `我 commit 错了`
- `怎么恢复`
- `误删分支`
- `push 错了`
- `git 救命`
- `git 怎么回退`
- `我把改动搞丢了`

Claude 会先采集当前 git 状态，再根据你描述的意图给出安全恢复命令。

## 内置脚本

### bin/state.sh — 采集 git 现状（只读）

```bash
bash skills/git-undo/bin/state.sh
```

输出：当前分支、工作区状态、最近 5 条提交、最近 10 条 reflog、上游信息、未暂存/未提交标志。

**纯只读，不执行任何写操作。**

## 覆盖场景

| 场景 | 推荐恢复方式 |
| --- | --- |
| 误 commit（还没 push） | `git reset --soft HEAD~1` 保留改动 |
| 想丢弃工作区改动 | `git restore <file>` / `git checkout -- <file>` |
| 误 `reset --hard` | `git reflog` 找回 SHA，`git reset --hard <sha>` |
| push 错分支 | `git revert` 或联系 reviewer；有权限才考虑 `push -f` |
| 误删本地分支 | `git branch <name> <sha>`（sha 从 reflog 查） |
| commit message 写错 | `git commit --amend`（未 push 时安全） |
| 想撤销已 push 的提交 | `git revert <sha>`（非破坏性，推荐） |

## 测试

```bash
bash tests/run.sh   # 离线，造临时 repo，断言 state.sh 输出正确
```

## License

[MIT](../../LICENSE)
