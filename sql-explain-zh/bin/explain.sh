#!/usr/bin/env bash
# explain.sh — (可选)帮跑 EXPLAIN,输出结果供 Claude 解读
# 用法:
#   explain.sh "<SQL>"            # SQL 作参数
#   echo "<SQL>" | explain.sh     # SQL 从 stdin
# 连接配置:读标准 MYSQL_* 环境变量
#   MYSQL_HOST / MYSQL_PORT / MYSQL_USER / MYSQL_PASSWORD / MYSQL_DATABASE
# 可用 MYSQL_CLI 覆盖 mysql 二进制路径(测试/自定义客户端):
#   MYSQL_CLI=/usr/local/mysql/bin/mysql explain.sh "SELECT 1"
# 没有 mysql 客户端时:优雅提示,exit 0(不崩),让用户手动粘贴 EXPLAIN 结果。
set -uo pipefail

MYSQL_CLI="${MYSQL_CLI:-mysql}"

# ---------- 1. 读 SQL ----------
if [ $# -ge 1 ] && [ -n "$1" ]; then
  SQL="$1"
else
  # 尝试从 stdin 读
  if [ -t 0 ]; then
    # stdin 是终端(没有管道输入)且没有参数 → 提示用法
    printf '用法:\n'
    printf '  explain.sh "<SQL>"                          # SQL 作参数\n'
    printf '  echo "<SQL>" | explain.sh                   # SQL 从 stdin\n'
    printf '\n没有传入 SQL。请提供要分析的查询语句。\n' >&2
    exit 1
  fi
  SQL="$(cat)"
fi

# 去掉首尾空白
SQL="$(printf '%s' "$SQL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [ -z "$SQL" ]; then
  printf 'ERROR: SQL 为空,请传入有效的查询语句。\n' >&2
  exit 1
fi

# ---------- 2. 检查 mysql 客户端 ----------
if ! command -v "$MYSQL_CLI" >/dev/null 2>&1; then
  printf '提示:未找到 mysql 客户端(%s)。\n' "$MYSQL_CLI"
  printf '你可以:\n'
  printf '  1. 安装 mysql 客户端并确保在 PATH 中\n'
  printf '  2. 设 MYSQL_CLI 指向已有的 mysql 二进制\n'
  printf '  3. 手动在数据库工具中跑以下语句,把结果粘给 Claude 解读:\n'
  printf '\n'
  printf 'EXPLAIN %s;\n' "$SQL"
  exit 0
fi

# ---------- 3. 读连接参数 ----------
DB_HOST="${MYSQL_HOST:-}"
DB_PORT="${MYSQL_PORT:-3306}"
DB_USER="${MYSQL_USER:-}"
DB_PASS="${MYSQL_PASSWORD:-}"
DB_NAME="${MYSQL_DATABASE:-}"

# 拼接连接参数
CONN_ARGS=()
[ -n "$DB_HOST" ] && CONN_ARGS+=("-h" "$DB_HOST")
[ -n "$DB_PORT" ] && CONN_ARGS+=("-P" "$DB_PORT")
[ -n "$DB_USER" ] && CONN_ARGS+=("-u" "$DB_USER")
[ -n "$DB_PASS" ] && CONN_ARGS+=("-p$DB_PASS")
[ -n "$DB_NAME" ] && CONN_ARGS+=("$DB_NAME")

# 检查至少有 host 或 user,否则也会尝试(本地 socket 也可能成功)
if [ -z "$DB_HOST" ] && [ -z "$DB_USER" ]; then
  printf '提示:未设置 MYSQL_HOST / MYSQL_USER 等连接变量。\n'
  printf '将尝试本地 socket 连接,失败时请手动跑:\n'
  printf '\nEXPLAIN %s;\n\n' "$SQL"
fi

# ---------- 4. 跑 EXPLAIN ----------
EXPLAIN_SQL="EXPLAIN ${SQL%;};"

printf 'SQL: %s\n' "$SQL"
printf 'EXPLAIN 结果:\n'
"$MYSQL_CLI" "${CONN_ARGS[@]+"${CONN_ARGS[@]}"}" \
  --table \
  -e "$EXPLAIN_SQL" 2>&1
STATUS=$?

if [ $STATUS -ne 0 ]; then
  printf '\n提示:EXPLAIN 执行失败(exit %d)。\n' "$STATUS"
  printf '请检查:\n'
  printf '  - MYSQL_HOST / MYSQL_USER / MYSQL_PASSWORD / MYSQL_DATABASE 是否正确\n'
  printf '  - mysql 客户端是否能连到目标数据库\n'
  printf '\n你也可以手动在数据库工具中跑以下语句,把结果粘给 Claude:\n'
  printf '\nEXPLAIN %s;\n' "$SQL"
  exit 0
fi
