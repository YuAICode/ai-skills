---
name: git-undo
description: 撤销 git 操作的安全向导。当用户说「帮我撤销/我 commit 错了/怎么恢复/误删分支/push 错了/git 救命/git 怎么回退/我把改动搞丢了」时触发。
---

# git-undo — git 撤销安全向导

把用户用中文描述的"出了什么事"，变成**安全的恢复命令 + 清晰解释 + 风险提示**。
能用非破坏性方式就不用破坏性；拿不准意图先问；reflog 是后悔药要善用。

## 何时触发

- 用户说"帮我撤销"、"我 commit 错了"、"怎么恢复"、"误删分支"、"push 错了"、"git 救命"
- 用户说"git 怎么回退"、"我把改动搞丢了"、"想反悔"、"提交错了"
- 用户遇到 git 操作失误，不知道怎么恢复

## 工作流

### 1. 采集当前 git 状态

先跑 state.sh 了解现状，再结合用户描述判断：

```bash
bash <skill>/bin/state.sh
```

state.sh 会输出（纯只读）：
- 当前分支名
- `git status -s`（工作区/暂存区状态）
- 最近 5 条 `git log --oneline`
- `git reflog` 最近 10 条
- 上游分支信息（有无、是否领先/落后）
- 是否有未暂存改动、是否有未提交改动

### 2. 确认用户意图（拿不准先问）

读完状态后，**先理解用户想达成什么目标**，再给命令。
常见误解：用户说"撤销 commit"可能是要：
- 保留改动但取消提交（`--soft`）
- 完全丢掉（`--hard`，破坏性）
- 保留提交历史但反转内容（`git revert`）

**意图不明时直接追问，不臆测。**

### 3. 按场景给安全恢复命令

#### 场景 A：误 commit，还没 push

```bash
# 保留改动、取消提交（最安全，推荐）
git reset --soft HEAD~1

# 取消提交并取消暂存（改动还在工作区）
git reset HEAD~1

# ⚠️ 破坏性：取消提交 + 丢弃改动（不可恢复）
git reset --hard HEAD~1
```

> 建议：先问用户是否要保留改动。默认推荐 `--soft`。

#### 场景 B：想丢弃工作区的未提交改动

```bash
# 丢弃单个文件的改动
git restore <file>
# 或（旧版 git）
git checkout -- <file>

# ⚠️ 破坏性：丢弃所有未暂存改动
git restore .

# ⚠️ 破坏性：同时清掉未跟踪文件
git clean -fd
```

> 警告：工作区改动一旦丢弃无法找回，执行前建议 `git stash` 兜底。

#### 场景 C：误执行了 `reset --hard`，想找回丢失的提交

reflog 是后悔药：

```bash
# 1. 查看 reflog 找到误操作前的 SHA
git reflog

# 2. 恢复到那个状态
git reset --hard <sha>
# 或只切到那个提交建新分支
git branch recover-branch <sha>
```

> reflog 默认保留 90 天，所以大部分情况都能找回。

#### 场景 D：push 错了分支

```bash
# 非破坏性（推荐）：在目标分支上 revert
git revert <sha>
git push

# ⚠️ 破坏性（需上游配合，有协作者时极危险）：
git push --force-with-lease origin <branch>
```

> 强烈建议先用 `revert`。`push -f` 会覆盖他人工作，多人协作时须取得团队同意。

#### 场景 E：误删本地分支

```bash
# 1. 从 reflog 找到该分支最后的 SHA
git reflog --all | grep <branch-name>
# 或
git reflog

# 2. 重建分支
git branch <branch-name> <sha>
```

> 如果已经 push 过，也可以从远端恢复：`git checkout -b <branch-name> origin/<branch-name>`

#### 场景 F：commit message 写错了

```bash
# 只改最后一条 commit（未 push 时安全）
git commit --amend
# 不打开编辑器直接改
git commit --amend -m "新的 commit 信息"
```

> ⚠️ 已 push 后 amend 会改变提交 SHA，需要 `push -f`，有协作者时慎用。

#### 场景 G：想撤销已 push 的提交

```bash
# 非破坏性（推荐）：生成反向提交，历史保留
git revert <sha>
git push

# ⚠️ 破坏性（改写历史，多人协作时危险）：
git reset --hard <sha>
git push --force-with-lease
```

> 已经 push 的历史应优先用 `revert`。`reset + push -f` 会影响所有从该分支拉取代码的人。

### 4. 破坏性命令的处理规则

凡涉及以下命令，**必须**：
1. 用醒目格式（如 `⚠️` 或 **【警告】**）说明风险
2. 建议先执行兜底操作（`git stash` 或记录当前 SHA）
3. 明确等待用户确认，**不替用户执行**

破坏性命令清单：
- `git reset --hard`
- `git push --force` / `git push -f` / `git push --force-with-lease`
- `git clean -fd`
- `git restore .`（全量丢弃）
- `git rebase`（改写历史时）

### 5. 输出模板

```markdown
## 你的现状

（基于 state.sh 输出，用中文描述当前分支、有无未提交改动、最近提交是什么）

## 理解你的意图

（复述用户想做什么；若有歧义，列出 2-3 种可能并追问）

## 恢复命令

```bash
# 推荐（非破坏性）
<命令>

# ⚠️ 破坏性备选（需确认）
<命令>
```

## 解释

（白话讲：这个命令做了什么，为什么安全/不安全）

## 风险提示

（如有破坏性操作，说明：会丢失什么、是否可找回、建议的兜底步骤）

## 兜底（执行前建议做）

```bash
git stash        # 或
git log --oneline -3   # 记下当前 SHA
```
```

## 硬规则

1. **能用非破坏性方式就不用破坏性**：`revert` 优先于 `reset`；`--soft` 优先于 `--hard`。
2. **不臆测用户意图**：意图不明时直接追问，不擅自选择破坏性路径。
3. **reflog 是后悔药**：大多数误操作都可通过 reflog 找回，优先指引用户查 reflog。
4. **破坏性命令必须显著警告**：用醒目标记（⚠️）提示风险，建议兜底后再执行，**等用户确认**。
5. **脚本只读，不替用户执行恢复命令**：state.sh 是采集工具；恢复命令展示给用户自行执行。
6. **不替用户做 push -f**：即使用户说"帮我 force push"，也只给命令、不执行；需显示风险后由用户自己操作。
7. **上下文不足时追问**：若不知道是哪个分支、哪条提交、push 到了哪里，先问清楚。

## 边界

- 只处理本地和已知远端状态；无法访问用户的远端仓库。
- 不扫历史仓库的所有 reflog（只看最近 10 条），若找不到需提示用户增加范围。
- 不替用户执行任何命令，只给命令和解释。
- 若用户的 git 版本较旧（< 2.23），`git restore` 不可用，提示用 `git checkout --`。
