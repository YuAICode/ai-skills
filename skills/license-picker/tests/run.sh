#!/usr/bin/env bash
# license-picker 测试:验证生成、填充、防覆盖、未知 id、copyleft 指引。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADD="$DIR/../bin/add-license.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ if eval "$2"; then printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); else printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); fi; }

echo "== MIT 生成 + 填充 =="
bash "$ADD" MIT "Alice" 2026 --dir "$TMP" >/dev/null 2>&1
ok "生成 LICENSE 文件"   "[ -f '$TMP/LICENSE' ]"
ok "含 MIT License"      "grep -q 'MIT License' '$TMP/LICENSE'"
ok "填入 author"         "grep -q 'Alice' '$TMP/LICENSE'"
ok "填入 year"           "grep -q '2026' '$TMP/LICENSE'"
ok "占位符已替换干净"     "! grep -q '\[year\]\|\[fullname\]' '$TMP/LICENSE'"

echo "== 防覆盖 =="
ok "已存在不覆盖(exit 非0)" "! bash '$ADD' MIT X 2026 --dir '$TMP' 2>/dev/null"
ok "--force 可覆盖"          "bash '$ADD' ISC Bob 2025 --dir '$TMP' --force >/dev/null 2>&1 && grep -q 'ISC License' '$TMP/LICENSE'"

echo "== 其它协议 =="
T2="$TMP/b"; mkdir -p "$T2"
ok "BSD-3-Clause 生成"   "bash '$ADD' BSD-3-Clause Carol 2026 --dir '$T2' >/dev/null 2>&1 && grep -q 'BSD 3-Clause' '$T2/LICENSE'"
T3="$TMP/c"; mkdir -p "$T3"
ok "Unlicense 生成"      "bash '$ADD' Unlicense '' '' --dir '$T3' >/dev/null 2>&1 && grep -q 'public domain' '$T3/LICENSE'"

echo "== 防御 / 指引 =="
ok "未知 id 报错(exit 非0)"  "! bash '$ADD' NOPE-1.0 --dir '$TMP' 2>/dev/null"
out_unknown="$(bash "$ADD" NOPE-1.0 --dir "$TMP" 2>&1 || true)"
ok "未知 id 列出支持清单"     "printf '%s' \"\$out_unknown\" | grep -q 'MIT'"
out_apache="$(bash "$ADD" Apache-2.0 --dir "$TMP" 2>&1 || true)"
ok "Apache-2.0 给指引"        "printf '%s' \"\$out_apache\" | grep -q 'apache.org'"
out_gpl="$(bash "$ADD" GPL-3.0 --dir "$TMP" 2>&1 || true)"
ok "GPL-3.0 给指引"           "printf '%s' \"\$out_gpl\" | grep -q 'gnu.org'"
ok "缺 id 报错"               "! bash '$ADD' 2>/dev/null"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
