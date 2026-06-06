#!/usr/bin/env bash
# doc-sync 测试:临时 repo,造改动文件 + 文档引用,验证候选命中/不命中。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIND="$DIR/../bin/find-stale-docs.sh"
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

# ---- 建临时 git repo ----
cd "$TMP"
git init -q
git config user.email t@t.co
git config user.name t
git config commit.gpgsign false

# 创建初始文件:src/foo.go + docs/guide.md(引用 foo)+ docs/other.md(不引用)
mkdir -p src docs
cat > src/foo.go <<'GOEOF'
package main
// Foo 是核心逻辑
func Foo() {}
GOEOF

cat > docs/guide.md <<'MDEOF'
# 指南

本文档描述 foo 模块的用法。

参见 src/foo.go 获取实现细节。
MDEOF

cat > docs/other.md <<'MDEOF'
# 其他文档

这里完全不引用任何改动相关内容。
MDEOF

cat > README.md <<'MDEOF'
# 项目根 README

与改动无关的顶层说明。
MDEOF

git add src/foo.go docs/guide.md docs/other.md README.md
git -c commit.gpgsign=false commit -q -m "chore: 初始化"
git tag v0.1.0

# ---- 在 main 分支上改动 foo.go ----
echo "// 新增 Bar 函数" >> src/foo.go
git add src/foo.go
git -c commit.gpgsign=false commit -q -m "feat: 新增 Bar 函数"

echo "== 场景1:guide.md 引用 foo,应被列为候选 =="
out="$(bash "$FIND" v0.1.0)"

ok "STALE_DOCS 行存在"       "printf '%s' \"\$out\" | grep -q 'STALE_DOCS:'"
ok "候选数大于 0"             "printf '%s' \"\$out\" | grep -qE 'STALE_DOCS: [1-9]'"
ok "guide.md 被列为候选"     "printf '%s' \"\$out\" | grep -q 'docs/guide.md'"
ok "other.md 不在候选中"     "! printf '%s' \"\$out\" | grep -q 'docs/other.md'"
ok "根 README 不在候选中"    "! printf '%s' \"\$out\" | grep -q 'README.md'"

echo ""
echo "== 场景2:新增 src/bar.go,无文档引用 bar,候选应为 0 =="
cat > src/bar.go <<'GOEOF'
package main
func Bar() {}
GOEOF
git add src/bar.go
git -c commit.gpgsign=false commit -q -m "feat: 新增 bar.go"
git tag v0.2.0

# 只看最新这一个提交(bar.go 被加入,但无文档引用 bar)
out2="$(bash "$FIND" HEAD~1)"
ok "bar 改动后候选为 0 条"   "printf '%s' \"\$out2\" | grep -qE 'STALE_DOCS: 0'"
ok "other.md 仍不在候选中"   "! printf '%s' \"\$out2\" | grep -q 'docs/other.md'"

echo ""
echo "== 场景3:docs/guide.md 引用 bar,现在应被候选 =="
echo "参见 bar.go 模块。" >> docs/guide.md
git add docs/guide.md
git -c commit.gpgsign=false commit -q -m "docs: 提到 bar.go"
git tag v0.3.0

# 再改一次 bar.go
echo "// 修改" >> src/bar.go
git add src/bar.go
git -c commit.gpgsign=false commit -q -m "fix: 修改 bar"

out3="$(bash "$FIND" v0.3.0)"
ok "guide.md 引用 bar 被候选" "printf '%s' \"\$out3\" | grep -q 'docs/guide.md'"
ok "other.md 仍不被候选"      "! printf '%s' \"\$out3\" | grep -q 'docs/other.md'"

echo ""
echo "== 场景4:无改动(与 HEAD 对比)——零候选 =="
# 当前 HEAD 没有更多改动
out4="$(bash "$FIND" HEAD)"
ok "无改动时 CHANGED_FILES 为空" "printf '%s' \"\$out4\" | grep -q 'CHANGED_FILES: (无改动)'"

echo ""
echo "== 场景5:非 git 目录应报错退出 1 =="
out5_rc=0
(cd /tmp && bash "$FIND" 2>/dev/null) || out5_rc=$?
ok "非 git 目录退出码非 0" "[ \"\$out5_rc\" -ne 0 ]"

echo ""
echo "== 场景6:基点不存在时应报错退出 1 =="
out6_rc=0
bash "$FIND" "nonexistent-ref-xyz" 2>/dev/null || out6_rc=$?
ok "无效基点退出码非 0" "[ \"\$out6_rc\" -ne 0 ]"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
