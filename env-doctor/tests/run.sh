#!/usr/bin/env bash
# env-doctor 测试:临时目录造 .env.example + .env,验证缺失/空值检测及退出码。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin/check-env.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# ---------- 工具:断言退出码 ----------
assert() {
  local want="$1" name="$2"; shift 2
  local got=0
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 %s,实际 %s)${NC}\n" "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# ---------- 工具:断言输出含某字符串 ----------
assert_contains() {
  local name="$1" needle="$2"; shift 2
  local out got=0
  out="$("$@" 2>&1)" || got=$?
  if printf '%s' "$out" | grep -q "$needle"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (未找到 '%s')${NC}\n" "$name" "$needle"
    fail=$((fail+1))
  fi
}

# ---------- 工具:断言输出不含某字符串 ----------
assert_not_contains() {
  local name="$1" needle="$2"; shift 2
  local out got=0
  out="$("$@" 2>&1)" || got=$?
  if ! printf '%s' "$out" | grep -q "$needle"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (不应含 '%s')${NC}\n" "$name" "$needle"
    fail=$((fail+1))
  fi
}

# ============================================================
# 场景一:有 .env.example,无 .env  → 告警但 exit 0
# ============================================================
echo "== 场景一:有 .env.example,但缺 .env =="
D1="$TMP/s1"; mkdir -p "$D1"
printf 'A=foo\nB=bar\nC=baz\n' > "$D1/.env.example"

assert 0 "仅有模板没有 .env → exit 0" \
  bash "$BIN" "$D1"

assert_contains "输出中提到 .env" ".env" \
  bash "$BIN" "$D1"

# ============================================================
# 场景二:有 .env.example(A B C) + .env(A=x, B=空, 缺C) → exit 2
# ============================================================
echo ""
echo "== 场景二:C 缺失 + B 值为空 → exit 2 =="
D2="$TMP/s2"; mkdir -p "$D2"
printf 'A=hello\nB=world\nC=secret\n' > "$D2/.env.example"
printf 'A=actual_value\nB=\n' > "$D2/.env"

assert 2 "C 缺失 + B 空 → exit 2" \
  bash "$BIN" "$D2"

assert_contains "报告缺失 key C" "C" \
  bash "$BIN" "$D2"

assert_contains "报告空值 key B" "B" \
  bash "$BIN" "$D2"

# C 应出现在缺失列表
{
  out="$(bash "$BIN" "$D2" 2>&1)" || true
  if printf '%s' "$out" | grep -qE '\[缺失\].*C'; then
    printf "${GREEN}  ✓ C 出现在缺失列表${NC}\n"; pass=$((pass+1))
  else
    printf "${RED}  ✗ C 未出现在缺失列表${NC}\n"; fail=$((fail+1))
  fi
  # B 应出现在空值列表
  if printf '%s' "$out" | grep -qE '\[警告\].*B.*值为空|B.*值为空'; then
    printf "${GREEN}  ✓ B 出现在空值列表${NC}\n"; pass=$((pass+1))
  else
    printf "${RED}  ✗ B 未出现在空值列表${NC}\n"; fail=$((fail+1))
  fi
  # A 不应在缺失列表里
  if ! printf '%s' "$out" | grep -qE '\[缺失\].*\bA\b'; then
    printf "${GREEN}  ✓ A 不在缺失列表里${NC}\n"; pass=$((pass+1))
  else
    printf "${RED}  ✗ A 错误地出现在缺失列表${NC}\n"; fail=$((fail+1))
  fi
}

# ============================================================
# 场景三:完全匹配 — .env.example 与 .env 的 key + 值都有 → exit 0
# ============================================================
echo ""
echo "== 场景三:完全匹配 → exit 0 =="
D3="$TMP/s3"; mkdir -p "$D3"
printf 'A=x\nB=y\nC=z\n' > "$D3/.env.example"
printf 'A=foo\nB=bar\nC=baz\n' > "$D3/.env"

assert 0 "完全匹配 → exit 0" \
  bash "$BIN" "$D3"

assert_contains "输出配置完整提示" "完整" \
  bash "$BIN" "$D3"

# ============================================================
# 场景四:.env.sample 变体名也能被识别
# ============================================================
echo ""
echo "== 场景四:.env.sample 变体名 =="
D4="$TMP/s4"; mkdir -p "$D4"
printf 'TOKEN=placeholder\n' > "$D4/.env.sample"
printf 'TOKEN=abc\n' > "$D4/.env"

assert 0 ".env.sample 被正确识别且 token 有值 → exit 0" \
  bash "$BIN" "$D4"

# ============================================================
# 场景五:没有模板也没有 .env → exit 0(无可对比,仅提示)
# ============================================================
echo ""
echo "== 场景五:无模板无 .env → exit 0 =="
D5="$TMP/s5"; mkdir -p "$D5"

assert 0 "无模板无 .env → exit 0" \
  bash "$BIN" "$D5"

# ============================================================
# 场景六:.env 有注释行和空行不影响解析
# ============================================================
echo ""
echo "== 场景六:模板含注释行和空行,不应被当 key =="
D6="$TMP/s6"; mkdir -p "$D6"
printf '# 这是注释\nDB_HOST=localhost\n\n# 另一个注释\nDB_PORT=5432\n' > "$D6/.env.example"
printf 'DB_HOST=127.0.0.1\nDB_PORT=3306\n' > "$D6/.env"

assert 0 "注释/空行不干扰 key 解析 → exit 0" \
  bash "$BIN" "$D6"

# ============================================================
# 场景七:目录不存在 → exit 1
# ============================================================
echo ""
echo "== 场景七:目录不存在 → exit 1 =="
assert 1 "目录不存在 → exit 1" \
  bash "$BIN" "$TMP/nonexistent_dir_xyz"

# ---------- 汇总 ----------
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
