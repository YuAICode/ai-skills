# conflict-resolver-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/conflict-resolver-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

把 `git merge` / `git rebase` 产生的冲突块用中文逐条讲清——ours 想做什么、theirs 想做什么、冲突点在哪、建议怎么合——然后等用户确认,再给出合并后的内容让用户自己应用。**不自动改任何文件。**

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r conflict-resolver-zh ~/.claude/skills/
```

## 用法

### 作为 Claude Code skill

遇到冲突时跟 Claude 说:

- "帮我看冲突"
- "merge 有冲突,解一下"
- "conflict 怎么改"

Claude 会自动执行 `bin/list-conflicts.sh` 列出冲突块,然后用中文逐条解读,**等你确认后**才给出合并内容。

### 手动运行脚本(可独立使用)

```bash
# 扫描当前目录
bash bin/list-conflicts.sh

# 扫描指定目录
bash bin/list-conflicts.sh /path/to/repo
```

输出示例:

```
=== 文件: /path/to/repo/feature.py ===

--- 冲突块 #1 (行 2–6) ---
[ours / 当前分支]
  3:     return f"你好,{name}"
[theirs / 传入分支]
  5:     return f"Hello, {name}"

共发现 1 个冲突块,请逐一确认解决方式后再 git add。
```

- 无冲突时输出 `无冲突`，exit 0
- 有冲突时列出文件、块号、行号、ours/theirs 内容，exit 0（列出不算错误）
- 优先用 `git diff --name-only --diff-filter=U`；不在 git 仓库时退而用 `grep` 扫描

## 测试

```bash
bash tests/run.sh   # 14 项，离线，无外部依赖
```

## 硬规则

- **不自动解决冲突**:无论把握多大,都等用户明确确认后再给出最终内容
- **不做任何 git 写操作**:不执行 `git add`、`git commit`、文件写入等
- **语义冲突提醒人工核对**:两边都改了同一段逻辑时,明确标注不能机械取一边
- **纯 bash,零外部依赖**,bash 3.2 兼容

## License

[MIT](../../LICENSE)
