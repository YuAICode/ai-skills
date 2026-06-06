# commit-guard-zh 🛡️

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/commit-guard-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

提交/推送前的本地护栏 + 中文 commit 助手。把密钥、迁移炸弹、误推主分支挡在提交之前;干净了再帮你写一条规范的中文 commit。

## ✨ 四件事

| 检查 | 做什么 | 形式 |
| --- | --- | --- |
| **secret-scan** | 扫 staged diff 的密钥/凭据(私钥块、AWS/GitHub/Slack token、firebase JSON、`.p8`/`.pem`、长密码赋值) | 脚本(hook + skill) |
| **gorm-mysql-check** | 扫 staged `.go` 的 GORM×MySQL 非法写法(TEXT/BLOB/JSON 列带 `default:` → MySQL Error 1101) | 脚本(默认关) |
| **push-guard** | 推受保护分支需确认 + 防把 `.env`/密钥文件推上去 | 脚本(hook + skill) |
| **markdownlint** | 对 staged `.md` 跑 markdownlint(需 markdownlint-cli,默认关) | 脚本(默认关) |
| **commit-zh** | 从 `git diff` 生成中文 conventional commit | Claude(skill) |

> 核心检查零外部依赖(纯 bash + grep + git);markdownlint 是唯一可选的外部依赖,未装则自动跳过、绝不阻断。全部不联网、不扫历史。

## 🚀 用法

### A. 当 Claude Code skill(含中文 commit)

把目录拷进 skills 目录,重启 Claude Code:

```bash
cp -r commit-guard-zh ~/.claude/skills/
```

之后跟 Claude 说**"准备提交 / 帮我 commit / 要 push 了"** 即触发:跑检查 → 中文报告问题 → 干净的话生成中文 commit。

### B. 装成 git hook(不依赖 Claude,手动 git 也有护栏)

在目标 repo 里跑安装器,把确定性检查装进 `pre-commit` / `pre-push`:

```bash
bash /path/to/commit-guard-zh/install.sh          # 当前 repo
bash /path/to/commit-guard-zh/install.sh ~/proj   # 指定 repo
```

- 已有同名 hook 会自动备份为 `*.pre-commit-guard.bak`。
- 卸载:`bash uninstall.sh [repo路径]`。

推受保护分支时(被拦):

```bash
COMMIT_GUARD_CONFIRM=1 git push
```

## ⚙️ 配置

安装器会在 repo 根生成 `.commit-guard.sh`(可改可提交):

```sh
BRANCH_PROTECT="main master"   # 受保护分支
ENABLE_GORM_CHECK=0            # Go+GORM 项目设 1 才开
ENABLE_MD_LINT=0              # 设 1 启用 markdownlint(需 markdownlint-cli;未装自动跳过)
SECRET_WHITELIST=""           # secret 误报白名单(extended regex),如 'testdata/|docs/'
```

## 🧪 测试

```bash
bash tests/run.sh   # 离线,对每个检查喂正例/反例断言退出码
```

## 退出码约定

`0` 通过 · `0`+stderr 警告 · `2`+stderr 拦截(git hook 会中止操作)。

## 📄 License

[MIT](../../LICENSE)
