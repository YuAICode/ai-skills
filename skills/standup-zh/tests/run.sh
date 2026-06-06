#!/usr/bin/env bash
# standup-zh 测试:临时 repo 造提交,验证 collect-activity.sh 的区间过滤、author 过滤、头部输出。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$DIR/../bin/collect-activity.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ if eval "$2"; then printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); else printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); fi; }

cd "$TMP"
git init -q
git config user.email "alice@example.com"
git config user.name "Alice"

# 造 alice 的提交
c(){ git -c commit.gpgsign=false commit -q --allow-empty -m "$1"; }
c "feat: 新增用户登录接口"
c "fix: 修复空指针异常"
c "refactor: 重构认证模块"

# ---- 场景1:默认 since("1 day ago"),默认 author(当前 user.email = alice) ----
echo "== 场景1:默认参数(1 day ago,当前作者 alice) =="
out="$(bash "$COLLECT")"
ok "输出含 RANGE 头"        "printf '%s' \"\$out\" | grep -q '^RANGE:'"
ok "输出含 AUTHOR 头"       "printf '%s' \"\$out\" | grep -q '^AUTHOR: alice@example.com'"
ok "输出含 COMMITS 段"      "printf '%s' \"\$out\" | grep -q '^COMMITS:'"
ok "输出含 STATS 段"        "printf '%s' \"\$out\" | grep -q '^STATS:'"
ok "采到 feat 提交"         "printf '%s' \"\$out\" | grep -q '新增用户登录接口'"
ok "采到 fix 提交"          "printf '%s' \"\$out\" | grep -q '修复空指针异常'"
ok "采到 refactor 提交"     "printf '%s' \"\$out\" | grep -q '重构认证模块'"

# ---- 场景2:显式传 since,author 过滤 alice ----
echo "== 场景2:显式 since + author 过滤 =="
out2="$(bash "$COLLECT" "1 day ago" "alice@example.com")"
ok "显式 author 参数生效"   "printf '%s' \"\$out2\" | grep -q '^AUTHOR: alice@example.com'"
ok "RANGE 含传入的 since"   "printf '%s' \"\$out2\" | grep -q \"RANGE: since '1 day ago'\""
ok "仍能采到提交"           "printf '%s' \"\$out2\" | grep -q '新增用户登录接口'"

# ---- 场景3:author 过滤 — 用另一个 author,不应采到 alice 的提交 ----
echo "== 场景3:author 过滤(bob 无提交) =="
out3="$(bash "$COLLECT" "1 day ago" "bob@example.com")"
ok "bob author 头正确"      "printf '%s' \"\$out3\" | grep -q '^AUTHOR: bob@example.com'"
ok "过滤后不含 alice 提交"  "! printf '%s' \"\$out3\" | grep -q '新增用户登录接口'"

# ---- 场景4:since 设为将来时间,应无提交 ----
echo "== 场景4:since 为将来时间,COMMITS 段为空 =="
out4="$(bash "$COLLECT" "2099-01-01" "alice@example.com")"
ok "COMMITS 段存在但无内容"  "printf '%s' \"\$out4\" | grep -q '^COMMITS:'"
ok "不含任何提交 subject"    "! printf '%s' \"\$out4\" | grep -q '新增用户登录接口'"

# ---- 场景5:非 git 目录应报错退出非零 ----
echo "== 场景5:非 git 目录报错 =="
NOTGIT="$(mktemp -d)"
trap 'rm -rf "$TMP" "$NOTGIT"' EXIT
ok "非 git 目录退出码非零"  "! bash -c \"cd \\\"\$NOTGIT\\\" && bash '\$COLLECT'\" 2>/dev/null"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
