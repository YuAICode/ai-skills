# sql-explain-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/sql-explain-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

解读慢查询的 `EXPLAIN` 输出,给中文优化建议——索引、扫描行数、回表、filesort、临时表一网打尽。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r sql-explain-zh ~/.claude/skills/
```

## 用法

### 有 MySQL 连接时

```bash
export MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306
export MYSQL_USER=root MYSQL_PASSWORD=secret MYSQL_DATABASE=mydb

# SQL 作参数
bash sql-explain-zh/bin/explain.sh "SELECT * FROM orders WHERE user_id = 1"

# 或从 stdin
echo "SELECT * FROM orders WHERE user_id = 1" | bash sql-explain-zh/bin/explain.sh
```

把输出粘给 Claude:"帮我解读这个 EXPLAIN"。

### 只有 EXPLAIN 结果时

把 EXPLAIN 结果直接粘给 Claude 即可,无需脚本。

说"帮我看下这个 EXPLAIN"、"这个 SQL 好慢"、"慢查询优化"都能触发。

### 自定义 mysql 客户端

```bash
MYSQL_CLI=/usr/local/mysql/bin/mysql bash sql-explain-zh/bin/explain.sh "SELECT 1"
```

## 依赖

- **可选**:mysql 客户端(默认 `mysql`,可用 `MYSQL_CLI` 覆盖二进制路径)
- **可选**:连接环境变量 `MYSQL_HOST` / `MYSQL_PORT` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_DATABASE`
- 没有客户端或连接信息时,脚本优雅提示,不崩;核心解读全靠 Claude。

## 测试

```bash
bash sql-explain-zh/tests/run.sh   # 用 stub 验证,不依赖真实数据库
```

## License

[MIT](../../LICENSE)
