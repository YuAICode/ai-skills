#!/usr/bin/env bash
# gitignore-doctor 测试:临时 git repo,验证 check.sh 检测逻辑与退出码。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# assert <期望退出码> <说明> -- <命令...>
assert() {
  local want="$1" name="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 %s,实际 %s)${NC}\n" "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# assert_output_contains <关键字> <说明> -- <命令...>
assert_output_contains() {
  local keyword="$1" name="$2"; shift 3
  local out
  out="$("$@" 2>&1 || true)"
  if printf '%s' "$out" | grep -q "$keyword"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (输出中未找到:%s)${NC}\n" "$name" "$keyword"
    fail=$((fail+1))
  fi
}

# ---- 初始化临时 git repo ----
REPO="$TMP/testrepo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@test.co"
git -C "$REPO" config user.name "test"

echo "== 场景1:干净 repo(无垃圾文件) =="

# 只有正常文件
echo "hello" > "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" -c commit.gpgsign=false commit -q -m "init"

assert 0 "干净 repo exit 0" -- bash "$BIN/check.sh" "$REPO"

echo "== 场景2:已追踪的垃圾文件(.DS_Store + node_modules) =="

# 造文件并 git add(模拟已追踪)
mkdir -p "$REPO/node_modules/lodash"
echo "fake module" > "$REPO/node_modules/lodash/index.js"
touch "$REPO/.DS_Store"

# git add 这两个垃圾文件(故意追踪它们)
git -C "$REPO" add -f "$REPO/node_modules/lodash/index.js"
git -C "$REPO" add -f "$REPO/.DS_Store"
git -C "$REPO" -c commit.gpgsign=false commit -q -m "add junk"

assert 2 "已追踪垃圾 exit 2" -- bash "$BIN/check.sh" "$REPO"
assert_output_contains ".DS_Store" ".DS_Store 出现在报告中" -- bash "$BIN/check.sh" "$REPO"
assert_output_contains "node_modules" "node_modules 出现在报告中" -- bash "$BIN/check.sh" "$REPO"
assert_output_contains "git rm --cached" "报告含 git rm --cached 提示" -- bash "$BIN/check.sh" "$REPO"

echo "== 场景3:未追踪但未被忽略的垃圾文件(建议加 .gitignore,exit 0) =="

REPO2="$TMP/testrepo2"
mkdir -p "$REPO2"
git -C "$REPO2" init -q
git -C "$REPO2" config user.email "test@test.co"
git -C "$REPO2" config user.name "test"
echo "hello" > "$REPO2/README.md"
git -C "$REPO2" add README.md
git -C "$REPO2" -c commit.gpgsign=false commit -q -m "init"

# 造未追踪的垃圾文件(不 add)
touch "$REPO2/.DS_Store"
mkdir -p "$REPO2/dist"
echo "bundle" > "$REPO2/dist/app.js"

assert 0 "未追踪垃圾 exit 0" -- bash "$BIN/check.sh" "$REPO2"
assert_output_contains "建议加进 .gitignore" "输出含建议块" -- bash "$BIN/check.sh" "$REPO2"

echo "== 场景4:.env 文件已被追踪 =="

REPO3="$TMP/testrepo3"
mkdir -p "$REPO3"
git -C "$REPO3" init -q
git -C "$REPO3" config user.email "test@test.co"
git -C "$REPO3" config user.name "test"

echo "SECRET=123" > "$REPO3/.env"
echo "SECRET=456" > "$REPO3/.env.local"
git -C "$REPO3" add -f "$REPO3/.env" "$REPO3/.env.local"
git -C "$REPO3" -c commit.gpgsign=false commit -q -m "oops env"

assert 2 ".env 已追踪 exit 2" -- bash "$BIN/check.sh" "$REPO3"
assert_output_contains ".env" ".env 出现在报告中" -- bash "$BIN/check.sh" "$REPO3"

echo "== 场景5:非 git 目录 =="

NOTGIT="$TMP/notgit"
mkdir -p "$NOTGIT"
assert 1 "非 git 目录 exit 1" -- bash "$BIN/check.sh" "$NOTGIT"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
