---
name: commit-guard-zh
description: 提交/推送前的本地护栏 + 中文 commit 助手。当用户说"准备提交 / 帮我 commit / 要 push 了 / 提交一下"时触发。跑三项确定性检查(密钥扫描、GORM×MySQL 非法写法、主分支保护),全过后用 git diff 生成中文 conventional commit。Use when the user is about to commit or push and wants pre-flight checks plus a Chinese commit message.
---

# commit-guard-zh — 提交/推送前护栏 + 中文 commit

提交前在本地把关,别让密钥、迁移炸弹、误推主分支溜进仓库;干净了再帮你写一条规范的中文 commit。

## 何时触发

用户说"准备提交 / 帮我 commit / 提交一下 / 要 push 了"等。

## 工作流

### 1. 跑检查(确定性脚本,在仓库根目录执行)

```bash
bash <skill>/bin/secret-scan.sh            # 扫 staged diff 的密钥/凭据
# 若该 repo 是 Go+GORM(.commit-guard.sh 里 ENABLE_GORM_CHECK=1):
bash <skill>/bin/gorm-mysql-check.sh       # 扫 staged .go 的 TEXT/JSON 带 DEFAULT
```

- 任一脚本 `exit 2` → **停下**。把 stderr 里的问题用中文讲清楚 + 给修法,等用户处理,**不要**擅自跳过或 `--no-verify`。
- 全 `exit 0` → 进入下一步。

### 2. 生成中文 commit

读 `git diff --cached`,生成一条 **conventional 前缀 + 中文描述**的 message:
- 前缀按改动性质:`feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:`
- 描述用中文;代码标识符、API、库名保持英文
- 多个改动点用 body 分条
- 展示给用户确认后再 `git commit`

### 3. 若要推送

```bash
bash <skill>/bin/push-guard.sh <分支名>
```
- 推到受保护分支(默认 main/master)时:**先确认本回合用户是否已明确授权推送主分支**(这是会自动部署/影响线上的高风险操作)。授权了再 `COMMIT_GUARD_CONFIRM=1 git push`。
- 脚本若报 env/密钥文件混进待推提交 → 停下,协助移除。

## 也可装成 git hook(不依赖 Claude)

确定性检查能装进目标 repo 的 `pre-commit` / `pre-push`,这样手动 git 操作也有护栏:

```bash
bash <skill>/install.sh /path/to/your-repo
```

详见 [README](./README.md)。

## 配置

目标 repo 根目录放 `.commit-guard.sh`(从 `config.example.sh` 复制):
- `BRANCH_PROTECT="main master"` — 受保护分支
- `ENABLE_GORM_CHECK=0` — 是否启用 GORM 检查(仅 Go+GORM 项目;默认关)
- `SECRET_WHITELIST=""` — secret 误报白名单(extended regex)

## 边界

- 只看本次 staged / 本次待推的提交,不扫历史、不联网。
- secret 命中**宁可误报也拦**,误报走白名单豁免。
- 不替代 CI,是本地前移的快速护栏。
