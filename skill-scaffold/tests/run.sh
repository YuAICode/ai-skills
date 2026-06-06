#!/usr/bin/env bash
# skill-scaffold 测试:在临时 git repo 里跑生成器,断言产物正确。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$DIR/../bin/new-skill.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ if eval "$2"; then printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); else printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); fi; }

# 造一个带 remote 的临时 repo
( cd "$TMP" && git init -q && git remote add origin git@github.com:DemoOrg/demo-repo.git )

echo "== 基本生成 =="
( cd "$TMP" && bash "$GEN" my-skill "一个测试用的中文描述。次句。" ) >/dev/null 2>&1
ok "SKILL.md 生成"            "[ -f '$TMP/my-skill/SKILL.md' ]"
ok "README.md 生成"          "[ -f '$TMP/my-skill/README.md' ]"
ok "frontmatter name 正确"    "grep -q '^name: my-skill\$' '$TMP/my-skill/SKILL.md'"
ok "frontmatter 含 description" "grep -q '^description: ' '$TMP/my-skill/SKILL.md'"
ok "徽章解析出 ORG/REPO"      "grep -q 'DemoOrg%2Fdemo--repo' '$TMP/my-skill/README.md'"
ok "徽章 tree 链接正确"       "grep -q 'tree/main/my-skill' '$TMP/my-skill/README.md'"

echo "== --bin 选项 =="
( cd "$TMP" && bash "$GEN" with-bin "带脚本的 skill。" --bin ) >/dev/null 2>&1
ok "bin/ 生成"               "[ -d '$TMP/with-bin/bin' ]"
ok "tests/run.sh 生成且可执行" "[ -x '$TMP/with-bin/tests/run.sh' ]"

echo "== 防御 =="
ok "拒绝非 kebab-case"        "! ( cd '$TMP' && bash '$GEN' Bad_Name '描述' ) 2>/dev/null"
ok "缺描述报错"              "! ( cd '$TMP' && bash '$GEN' lonely ) 2>/dev/null"
ok "已存在不覆盖"            "! ( cd '$TMP' && bash '$GEN' my-skill '又来一次' ) 2>/dev/null"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
