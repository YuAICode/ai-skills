#!/usr/bin/env bash
# conflict-resolver-zh 测试:临时目录造冲突文件,验证 list-conflicts.sh 的输出。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin/list-conflicts.sh"
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

# ---- 1. 造一个含单个冲突块的文件 ----
CONFLICT_FILE="$TMP/feature.py"
cat > "$CONFLICT_FILE" <<'PYEOF'
def greet(name):
<<<<<<< HEAD
    return f"你好,{name}"
=======
    return f"Hello, {name}"
>>>>>>> feature/english-greet
PYEOF

# ---- 2. 造一个含两个冲突块的文件 ----
CONFLICT_FILE2="$TMP/config.yml"
cat > "$CONFLICT_FILE2" <<'YMLEOF'
server:
  host: localhost
<<<<<<< HEAD
  port: 8080
=======
  port: 9090
>>>>>>> feature/port-change
logging:
<<<<<<< HEAD
  level: debug
=======
  level: info
>>>>>>> feature/log-level
YMLEOF

# ---- 3. 造一个无冲突的文件 ----
CLEAN_FILE="$TMP/clean.txt"
printf 'hello world\nno conflicts here\n' > "$CLEAN_FILE"

# ---- 4. 造仅含无冲突文件的目录 ----
CLEAN_DIR="$TMP/clean_dir"
mkdir -p "$CLEAN_DIR"
printf 'just normal content\n' > "$CLEAN_DIR/normal.txt"

echo "== 测试:有冲突文件的目录 =="
OUT="$(bash "$BIN" "$TMP")"

ok "脚本 exit 0(有冲突也不报错)" "bash '$BIN' '$TMP' >/dev/null 2>&1"
ok "输出包含冲突文件名 feature.py" "printf '%s' \"\$OUT\" | grep -q 'feature.py'"
ok "输出包含冲突文件名 config.yml" "printf '%s' \"\$OUT\" | grep -q 'config.yml'"
ok "输出包含 ours 标记" "printf '%s' \"\$OUT\" | grep -q '\[ours / 当前分支\]'"
ok "输出包含 theirs 标记" "printf '%s' \"\$OUT\" | grep -q '\[theirs / 传入分支\]'"
ok "ours 侧包含 '你好'" "printf '%s' \"\$OUT\" | grep -q '你好'"
ok "theirs 侧包含 'Hello'" "printf '%s' \"\$OUT\" | grep -q 'Hello'"
ok "config.yml 冲突块 #1 含 8080" "printf '%s' \"\$OUT\" | grep -q '8080'"
ok "config.yml 冲突块 #2 含 9090" "printf '%s' \"\$OUT\" | grep -q '9090'"
ok "输出含冲突块计数信息" "printf '%s' \"\$OUT\" | grep -q '冲突块'"

echo ""
echo "== 测试:无冲突目录 =="
OUT_CLEAN="$(bash "$BIN" "$CLEAN_DIR")"

ok "无冲突目录 exit 0" "bash '$BIN' '$CLEAN_DIR' >/dev/null 2>&1"
ok "无冲突目录输出'无冲突'" "printf '%s' \"\$OUT_CLEAN\" | grep -q '无冲突'"
ok "无冲突目录不含 ours 标记" "! printf '%s' \"\$OUT_CLEAN\" | grep -q '\[ours'"

echo ""
echo "== 测试:带行号输出 =="
ok "ours 行号标注存在" "printf '%s' \"\$OUT\" | grep -qE '[[:space:]]+[0-9]+: '"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
