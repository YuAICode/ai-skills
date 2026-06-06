#!/usr/bin/env bash
# changelog-zh 测试:临时 repo 造各类型提交,验证归类正确。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$DIR/../bin/collect-commits.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ if eval "$2"; then printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); else printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); fi; }

cd "$TMP"
git init -q; git config user.email t@t.co; git config user.name t
c(){ git -c commit.gpgsign=false commit -q --allow-empty -m "$1"; }

# ---- 阶段1:还没打 tag,测"全量"(无 tag → 自动 from 空 → 全历史)----
c "feat: 新增登录"
c "feat(api): 加分页"
c "fix: 修空指针"
c "docs: 更新 README"
c "随手改了点东西"          # 非规范 → other

echo "== 全量(无 tag,全历史)=="
out="$(bash "$COLLECT")"
ok "feat 分组存在"        "printf '%s' \"\$out\" | grep -qE '^### feat'"
ok "feat 计数为 2"        "printf '%s' \"\$out\" | grep -qE '^### feat \(×2\)'"
ok "归到 feat 的条目"     "printf '%s' \"\$out\" | grep -q '新增登录'"
ok "scope 提交也算 feat"  "printf '%s' \"\$out\" | grep -q '加分页'"
ok "非规范进 other"       "printf '%s' \"\$out\" | grep -A3 '### other' | grep -q '随手改了点东西'"
ok "subject 去掉类型前缀"  "! printf '%s' \"\$out\" | grep -q 'feat: 新增登录'"
ok "RANGE 从 <root>"      "printf '%s' \"\$out\" | grep -q 'RANGE: <root>..HEAD'"

# ---- 阶段2:打 tag 后再提交,测区间 + 自动取最近 tag ----
git tag v1.0.0
c "feat: tag 之后的新功能"
c "fix!: 破坏性修复"

echo "== 区间(tag 之后)=="
out2="$(bash "$COLLECT" v1.0.0 HEAD)"
ok "含 tag 后的 feat"     "printf '%s' \"\$out2\" | grep -q 'tag 之后的新功能'"
ok "fix! 破坏性归 fix"    "printf '%s' \"\$out2\" | grep -q '破坏性修复'"
ok "不含 tag 前的 feat"   "! printf '%s' \"\$out2\" | grep -q '新增登录'"

echo "== 自动取最近 tag =="
out3="$(bash "$COLLECT")"
ok "缺省 from=最近 tag"   "printf '%s' \"\$out3\" | grep -q 'RANGE: v1.0.0..HEAD'"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
