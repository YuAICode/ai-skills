#!/usr/bin/env bash
# pr-desc-zh 测试:临时 repo 造分支+提交,验证 collect.sh 采集正确。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$DIR/../bin/collect.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ if eval "$2"; then printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); else printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); fi; }

cd "$TMP"
git init -q; git config user.email t@t.co; git config user.name t
git checkout -q -b main
echo base > a.txt; git add a.txt; git -c commit.gpgsign=false commit -q -m "chore: init"
git checkout -q -b feature/x
echo one > b.txt; git add b.txt; git -c commit.gpgsign=false commit -q -m "feat: 加 b"
echo two > c.txt; git add c.txt; git -c commit.gpgsign=false commit -q -m "fix: 加 c"

out="$(bash "$COLLECT" main)"
ok "BASE 行存在"        "printf '%s' \"\$out\" | grep -q '^BASE: main'"
ok "采到 feat 提交"     "printf '%s' \"\$out\" | grep -q 'feat: 加 b'"
ok "采到 fix 提交"      "printf '%s' \"\$out\" | grep -q 'fix: 加 c'"
ok "不含 base 自身提交" "! printf '%s' \"\$out\" | grep -q 'chore: init'"
ok "FILES 列出 b.txt"   "printf '%s' \"\$out\" | grep -q 'b.txt'"
ok "有 DIFFSTAT 段"     "printf '%s' \"\$out\" | grep -q '^DIFFSTAT:'"

# 自动探测 base(无 origin 时回退 main)
out2="$(bash "$COLLECT")"
ok "无参数能自动定 base"  "printf '%s' \"\$out2\" | grep -q '^BASE: main'"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
