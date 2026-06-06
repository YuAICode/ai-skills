#!/usr/bin/env bash
# sql-explain-zh 测试:用 mysql stub 验证各场景,不依赖真实数据库。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPLAIN="$DIR/../bin/explain.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

ok(){
  local name="$1"; shift
  if eval "$@"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"; fail=$((fail+1))
  fi
}

# ---------- stub mysql:把收到的参数 + 固定 EXPLAIN 行原样打印 ----------
cat > "$TMP/mysql" <<'EOF'
#!/bin/sh
# 模拟 mysql 客户端:打印收到的参数 + 假 EXPLAIN 输出
echo "MYSQL_STUB_ARGS: $*"
echo "+----+-------------+--------+------+---------------+------+---------+------+------+-------------+"
echo "| id | select_type | table  | type | possible_keys | key  | key_len | ref  | rows | Extra       |"
echo "+----+-------------+--------+------+---------------+------+---------+------+------+-------------+"
echo "|  1 | SIMPLE      | orders | ALL  | NULL          | NULL | NULL    | NULL |  500 | Using where |"
echo "+----+-------------+--------+------+---------------+------+---------+------+------+-------------+"
EOF
chmod +x "$TMP/mysql"

SQL_SIMPLE="SELECT * FROM orders WHERE user_id = 1"

# ===== 场景 1: 有 stub 时调用并输出 EXPLAIN =====
echo "== 场景 1:stub mysql 客户端正常调用 =="
out="$(MYSQL_CLI="$TMP/mysql" MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_DATABASE=mydb \
  bash "$EXPLAIN" "$SQL_SIMPLE")"

ok "打印传入的 SQL"          "printf '%s' \"\$out\" | grep -q 'SQL: SELECT'"
ok "输出 EXPLAIN 结果字样"   "printf '%s' \"\$out\" | grep -qi 'EXPLAIN 结果'"
ok "stub 实际被调用"         "printf '%s' \"\$out\" | grep -q 'MYSQL_STUB_ARGS'"
ok "stub 输出 SIMPLE 行"     "printf '%s' \"\$out\" | grep -q 'SIMPLE'"
ok "传入 -e 参数(执行模式)"  "printf '%s' \"\$out\" | grep -q -- '-e'"

# ===== 场景 2: MYSQL_CLI 指向不存在的二进制 — 优雅提示且 exit 0 =====
echo "== 场景 2:MYSQL_CLI=/nonexistent — 优雅降级 =="
out2="$(MYSQL_CLI=/nonexistent bash "$EXPLAIN" "$SQL_SIMPLE")"
exit2=$?

ok "exit 0(不崩)" "[ \$exit2 -eq 0 ]"
ok "提示未找到客户端" "printf '%s' \"\$out2\" | grep -q '未找到'"
ok "给出手动跑的 SQL" "printf '%s' \"\$out2\" | grep -q 'EXPLAIN'"
ok "提示可设 MYSQL_CLI" "printf '%s' \"\$out2\" | grep -q 'MYSQL_CLI'"

# ===== 场景 3: 无 SQL 入参(参数和 stdin 都没有) =====
echo "== 场景 3:无 SQL 入参 =="
# 用 echo '' 给一个空 stdin 触发 stdin 分支;分开捕获 stdout+stderr 和退出码
out3="$(echo '' | MYSQL_CLI="$TMP/mysql" bash "$EXPLAIN" 2>&1)" && exit3=0 || exit3=$?

ok "空 SQL 时 exit 非 0" "[ \$exit3 -ne 0 ]"
ok "提示 SQL 为空"        "printf '%s' \"\$out3\" | grep -qi 'SQL\|空\|用法'"

# ===== 场景 4: SQL 从 stdin 传入 =====
echo "== 场景 4:SQL 从 stdin 传入 =="
out4="$(printf '%s' "$SQL_SIMPLE" | MYSQL_CLI="$TMP/mysql" MYSQL_HOST=127.0.0.1 MYSQL_USER=root \
  bash "$EXPLAIN")"

ok "stdin SQL 被正确读取"  "printf '%s' \"\$out4\" | grep -q 'SQL: SELECT'"
ok "stub 被调用"           "printf '%s' \"\$out4\" | grep -q 'MYSQL_STUB_ARGS'"

# ===== 场景 5: SQL 末尾多分号不崩 =====
echo "== 场景 5:SQL 末尾带分号 =="
out5="$(MYSQL_CLI="$TMP/mysql" MYSQL_HOST=127.0.0.1 MYSQL_USER=root \
  bash "$EXPLAIN" "SELECT 1;")"
exit5=$?

ok "有分号时 exit 0" "[ \$exit5 -eq 0 ]"
ok "stub 仍被调用"   "printf '%s' \"\$out5\" | grep -q 'MYSQL_STUB_ARGS'"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
