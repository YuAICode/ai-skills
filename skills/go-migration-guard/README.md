# go-migration-guard

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/go-migration-guard)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

启发式检查 GORM 模型改动是否可能缺少对应迁移文件(migration 覆盖)。基于 `git diff` 文本信号,不依赖数据库连接。

> **这是启发式提醒,不是保证。** 脚本只看 diff 里的文本信号;Claude 应结合实际 migration 文件内容判断。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r go-migration-guard ~/.claude/skills/
```

## 用法

### 在 Claude Code 中(推荐)

对话中说"检查迁移 / migration 覆盖了吗 / gorm 模型改了有没有加迁移"即可触发。

Claude 会自动调用 `bin/check-migration.sh`,分析输出并给出中文说明。

### 直接运行脚本

```bash
# 在目标 repo 根目录运行
bash <skill>/bin/check-migration.sh [base]

# 例:与 main 分支比较
bash ~/.claude/skills/go-migration-guard/bin/check-migration.sh main

# 例:与上一个 commit 比较
bash ~/.claude/skills/go-migration-guard/bin/check-migration.sh HEAD~1

# 不传 base:自动探测 main / master
bash ~/.claude/skills/go-migration-guard/bin/check-migration.sh
```

退出码:
- `0` — 没有检测到 gorm 字段变更,放行
- `2` — 检测到带 gorm tag 的字段新增/删除,需人工确认迁移覆盖

### 输出示例

```
[go-migration-guard] 启发式迁移覆盖检查
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

以下带 gorm tag 的 struct 字段在本次 diff 中有新增(+)或删除(-),
请确认这些字段变更有对应的 migration 覆盖(或 AutoMigrate 已含):

  + model/user.go: 	Name string `gorm:"type:varchar(64)"`

⛔  未发现任何迁移线索(migration 目录未动、无 AutoMigrate、无手动 DDL)。

  如果项目依赖手写 migration 文件:请补写对应迁移,否则生产库 schema 将与模型不一致。
  如果项目用 AutoMigrate:确认它在服务启动时会被执行,且已含上述字段。
  历史教训:迁移链断 → Lambda 跑新代码 + 旧 schema → 数据静默丢失。

注:本检查为启发式,不能保证迁移完整。Claude 应结合实际 migration 文件内容判断。
```

## 检测逻辑

| 检测项 | 方法 |
|---|---|
| gorm 字段新增 | diff 中 `+` 行且含 `gorm:"` |
| gorm 字段删除 | diff 中 `-` 行且含 `gorm:"` |
| migration 目录线索 | diff header 含 `/migration(s)/` 路径 |
| AutoMigrate 线索 | diff 新增行含 `AutoMigrate` |
| 手动 DDL 线索 | diff 新增行含 `AddColumn`/`DropColumn`/`AlterColumn` 等 |

## 与 commit-guard-zh 的区别

| | commit-guard-zh/gorm-mysql-check | go-migration-guard |
|---|---|---|
| 扫的是 | staged 的 TEXT/JSON 带 DEFAULT 非法写法 | diff 里 gorm 字段变更是否有迁移覆盖 |
| 关注点 | MySQL 语法错误 | 迁移链完整性 |
| 触发时机 | 提交前 | code review / 模型改动后 |

## 测试

```bash
bash tests/run.sh
```

无需真实 git repo,全部离线运行。

## License

[MIT](../../LICENSE)
