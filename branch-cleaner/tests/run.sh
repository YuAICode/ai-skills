#!/usr/bin/env bash
# branch-cleaner 测试:临时 repo,造 main + 已合并分支 + 未合并分支 + 陈旧分支,验证输出正确。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$DIR/../bin/list-branches.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

ok() {
  local name="$1"
  shift
  if eval "$@"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"
    fail=$((fail+1))
  fi
}

# 从输出中提取 MERGED 段(^MERGED: 到空行前)
merged_section() { printf '%s' "$1" | awk '/^MERGED:/{p=1} p && /^$/{exit} p{print}'; }
# 从输出中提取 STALE 段(^STALE: 到空行前)
stale_section()  { printf '%s' "$1" | awk '/^STALE:/{p=1}  p && /^$/{exit} p{print}'; }

# ---- 建立临时 repo ----
cd "$TMP"
git init -q
git config user.email t@t.co
git config user.name t

c() { git -c commit.gpgsign=false commit -q --allow-empty -m "$1"; }

# 在 main 上建初始提交
c "init: initial commit"

# 建 feature/merged:从 main 分出,再合并回 main
git checkout -q -b feature/merged
c "feat: 这个分支会被合并"
git checkout -q main
git -c commit.gpgsign=false merge -q --no-ff feature/merged -m "merge feature/merged"

# 建 feature/wip:从 main 分出,不合并
git checkout -q -b feature/wip
c "feat: 进行中,不合并"
git checkout -q main

# 建 feature/extra-protect:演示额外保护分支
git checkout -q -b feature/extra-protect
c "feat: 这个分支加入额外保护"
git checkout -q main

echo "== MERGED 组断言 =="

out="$(bash "$LIST")"

# feature/merged 应出现在 MERGED 组
ok "MERGED 含 feature/merged" "merged_section \"\$out\" | grep -q 'feature/merged'"

# main 不应出现在 MERGED 组(保护分支);只检查缩进的分支条目行,跳过含"main"的表头
ok "MERGED 不含 main" "! merged_section \"\$out\" | grep '^  ' | grep -qw 'main'"

# feature/wip 未合并,不应出现在 MERGED 组
ok "MERGED 不含 feature/wip" "! merged_section \"\$out\" | grep -q 'feature/wip'"

echo ""
echo "== STALE 组断言(新提交不应为陈旧) =="

# 刚提交的分支不应出现在 STALE(默认 60 天)
ok "STALE 不含 feature/wip(刚提交)"   "! stale_section \"\$out\" | grep -q 'feature/wip'"
ok "STALE 不含 feature/merged(刚提交)" "! stale_section \"\$out\" | grep -q 'feature/merged'"

echo ""
echo "== 额外保护分支 =="

# 传入额外保护分支 feature/extra-protect 时,它不应出现在 MERGED 组
out2="$(bash "$LIST" "feature/extra-protect")"
ok "额外保护分支不进 MERGED" "! merged_section \"\$out2\" | grep -q 'feature/extra-protect'"
ok "保护提示包含 feature/extra-protect" "printf '%s' \"\$out2\" | grep '保护分支' | grep -q 'feature/extra-protect'"

echo ""
echo "== 当前分支不出现在任何候选组 =="

git checkout -q feature/wip
out3="$(bash "$LIST")"
ok "当前分支 feature/wip 不在 MERGED" "! merged_section \"\$out3\" | grep -q 'feature/wip'"
ok "当前分支 feature/wip 不在 STALE"  "! stale_section  \"\$out3\" | grep -q 'feature/wip'"
ok "当前分支出现在保护提示" "printf '%s' \"\$out3\" | grep '保护分支' | grep -q 'feature/wip'"

echo ""
echo "== STALE 组(模拟陈旧,STALE_DAYS=0) =="

git checkout -q main
git checkout -q -b feature/old
c "feat: 这个分支很旧"
git checkout -q main

# STALE_DAYS=0:截止=now,commit_ts <= cutoff_ts → 进 STALE
out4="$(STALE_DAYS=0 bash "$LIST")"
ok "STALE_DAYS=0 时 feature/old 进 STALE" "stale_section \"\$out4\" | grep -q 'feature/old'"
ok "STALE_DAYS=0 时 main 不进 STALE"       "! stale_section \"\$out4\" | grep -qw 'main'"

echo ""
echo "== 非 git 目录报错 =="
ok "非 git 目录 exit 非零" "! ( cd /tmp && bash '$LIST' 2>/dev/null )"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
