---
name: go-migration-guard
description: 启发式检查 GORM 模型改动是否可能缺少对应迁移文件。当用户说「检查迁移 / migration 覆盖了吗 / gorm 模型改了有没有加迁移 / 迁移链断了 / 模型和数据库是否同步」时触发。
---

# go-migration-guard — GORM 迁移覆盖启发式检查

> **启发式提醒,不是保证。** 脚本只看 diff 里的文本信号,无法执行 SQL 或理解运行时逻辑。Claude 应结合实际 migration 文件内容判断,不要凭本 skill 的结论臆断"已覆盖"或"一定缺失"。

## 何时触发

用户说:
- "检查一下迁移 / migration 覆盖了吗"
- "gorm 模型改了,有没有加迁移"
- "迁移链断了 / 数据库和模型不同步了"
- "AutoMigrate 会自动加字段吗"
- 代码 review 时看到 `.go` 里有 gorm struct 改动,想确认迁移

## 用法

1. 在目标 repo 根目录运行(与 `git` 命令并列):

   ```bash
   bash <skill>/bin/check-migration.sh [base]
   # base 缺省:自动探测 main 或 master;也可传 HEAD~1、某 commit hash 等
   # 例:bash <skill>/bin/check-migration.sh main
   ```

   脚本输出两类信息:

   - **字段变更列表** — diff 里所有新增(`+`)或删除(`-`)且含 `gorm:"` 的 struct 字段行。
   - **迁移线索评估** — 若 diff 里完全没有迁移线索(没动 migration 目录、没有 `AutoMigrate` 相关字样),给出更强提醒。

   退出码:
   - `0` — 没有检测到 gorm 字段变更(放行)
   - `2` — 检测到字段变更,需人工确认

2. Claude 拿到输出后,应:
   - 列出脚本找到的字段变更。
   - 告知"是否在 diff 里看到迁移线索"。
   - 如有线索,请用户确认对应 migration 文件里是否真的涵盖了这些列。
   - 如无线索且项目不依赖 AutoMigrate,提醒用户补写 migration 文件。

## 确定性脚本做什么 / 不做什么

| 做 | 不做 |
|---|---|
| 扫 diff 中带 `gorm:"` 的新增/删除行 | 解析 SQL、运行数据库 |
| 检测 migration 目录是否有变动 | 验证 migration 内容是否正确 |
| 检测 AutoMigrate 字样 | 判断 AutoMigrate 是否在生产启用 |
| 给出字段名+所在文件 | 做 schema diff |

## 边界

- 只读 git diff,不改任何文件。
- 不与 `commit-guard-zh/bin/gorm-mysql-check.sh` 重复:那个脚本扫"TEXT/JSON 带 DEFAULT"这一特定非法写法;本 skill 聚焦"模型字段有没有迁移覆盖"的更宏观问题。
- 依赖 `git`;不依赖其他外部工具。
- 误报优于漏报:宁可提醒多余,也不想漏掉迁移缺失。
