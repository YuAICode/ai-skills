#!/usr/bin/env bash
# commit-roast 测试:临时 repo 造几条提交,断言 collect.sh 采到 subject、时间、改动统计。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$DIR/../bin/collect.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

ok(){
  local name="$1"
  local expr="$2"
  if eval "$expr"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"
    fail=$((fail+1))
  fi
}

# ---- 建临时 repo ----
cd "$TMP"
git init -q
git config user.email "roast@example.com"
git config user.name "Roast Tester"

# 辅助:带内容的提交(非 --allow-empty,让 shortstat 有数据)
write_commit(){
  local msg="$1"
  local file="file_$RANDOM.txt"
  printf 'line1\nline2\nline3\n' > "$file"
  git add "$file"
  git -c commit.gpgsign=false commit -q -m "$msg"
}

# 造一条敷衍提交
write_commit "fix"

# 造一条正常提交
write_commit "feat: 新增用户登录接口"

# 造一条深夜感 subject
write_commit "wip: 凌晨三点还没修好"

# ---- 场景1:默认参数(数量30,全部作者) ----
echo "== 场景1:默认参数 =="
out="$(bash "$COLLECT")"

ok "输出含 META 段"           "printf '%s' \"\$out\" | grep -q '^META:'"
ok "输出含 COMMITS 段"        "printf '%s' \"\$out\" | grep -q '^COMMITS:'"
ok "采到敷衍提交 fix"         "printf '%s' \"\$out\" | grep -q 'fix'"
ok "采到正常提交 subject"     "printf '%s' \"\$out\" | grep -q '新增用户登录接口'"
ok "采到 wip 提交"            "printf '%s' \"\$out\" | grep -q 'wip'"
ok "输出含 SHORTSTATS 段"     "printf '%s' \"\$out\" | grep -q '^SHORTSTATS:'"
ok "输出含 SUMMARY 段"        "printf '%s' \"\$out\" | grep -q '^SUMMARY:'"
ok "SUMMARY 有 total_commits" "printf '%s' \"\$out\" | grep -q 'total_commits'"
ok "SUMMARY 有 total_ins"     "printf '%s' \"\$out\" | grep -q 'total_ins'"
ok "SUMMARY 有 total_del"     "printf '%s' \"\$out\" | grep -q 'total_del'"
ok "每条含 ISO 日期格式"      "printf '%s' \"\$out\" | grep -qE '\\[[0-9a-f]+\\] [0-9]{4}-[0-9]{2}-[0-9]{2}'"

# ---- 场景2:指定数量 1,只采最近一条 ----
echo "== 场景2:数量=1 =="
out2="$(bash "$COLLECT" 1)"
hash_count="$(printf '%s' "$out2" | grep -cE '^\s+\[[0-9a-f]+\] [0-9]{4}' || true)"
ok "count=1 仅含一条 commit 行"  "[ \"$hash_count\" -eq 1 ]"
ok "采到最新提交(wip)"           "printf '%s' \"\$out2\" | grep -q 'wip'"

# ---- 场景3:author 过滤 —— 换一个不存在的作者 ----
echo "== 场景3:author 过滤(无匹配) =="
out3="$(bash "$COLLECT" 30 "nobody@nowhere.com")"
ok "author 参数出现在 META"   "printf '%s' \"\$out3\" | grep -q 'nobody@nowhere.com'"
ok "无匹配时显示无提交记录"   "printf '%s' \"\$out3\" | grep -q '无提交记录'"

# ---- 场景4:author 过滤 —— 用真实作者 ----
echo "== 场景4:author 过滤(有匹配) =="
out4="$(bash "$COLLECT" 30 "roast@example.com")"
ok "匹配到提交"               "printf '%s' \"\$out4\" | grep -q '新增用户登录接口'"

# ---- 场景5:非法 count 参数报错 ----
echo "== 场景5:非法 count 报错 =="
err_out="$(bash "$COLLECT" abc 2>&1 || true)"
ok "非法 count 输出 ERROR"    "printf '%s' \"\$err_out\" | grep -q 'ERROR'"

# ---- 场景6:非 git 目录应报错退出非零 ----
echo "== 场景6:非 git 目录报错 =="
NOTGIT="$(mktemp -d)"
trap 'rm -rf "$TMP" "$NOTGIT"' EXIT
ok "非 git 目录退出码非零"    "! bash -c \"cd \\\"\$NOTGIT\\\" && bash '\$COLLECT'\" 2>/dev/null"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
