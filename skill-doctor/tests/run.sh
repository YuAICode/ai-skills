#!/usr/bin/env bash
# skill-doctor 测试:在临时目录造合规/不合规 skill,断言退出码。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$DIR/../bin/lint-skill.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

assert() {
  local want="$1" name="$2"; shift 2
  local got
  "$@" >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 exit %s,实际 exit %s)${NC}\n" "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# ------------------------------------------------------------------
# 工具:造一个 skill 目录
# mk_skill <目录名> <frontmatter_name> [有无 README] [有无徽章] [有无 bin_sh] [有无 tests_run]
# ------------------------------------------------------------------
mk_skill() {
  local dir="$TMP/$1" fm_name="$2" has_readme="${3:-yes}" has_badge="${4:-yes}"
  local has_bin_sh="${5:-no}" has_tests="${6:-no}"
  mkdir -p "$dir"

  # SKILL.md
  cat > "$dir/SKILL.md" <<SKILLEOF
---
name: $fm_name
description: 这是一个测试用的 skill 描述,触发词在这里。
---

# $fm_name

## 何时触发
测试触发场景。
SKILLEOF

  # README.md
  if [ "$has_readme" = "yes" ]; then
    if [ "$has_badge" = "yes" ]; then
      cat > "$dir/README.md" <<READMEEOF
# $fm_name

[![Repo](https://img.shields.io/badge/GitHub-TestOrg%2Ftest--repo-181717?logo=github)](https://github.com/TestOrg/test-repo)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

这是测试用 README。
READMEEOF
    else
      cat > "$dir/README.md" <<READMEEOF
# $fm_name

这是没有徽章的测试用 README。
READMEEOF
    fi
  fi

  # bin/*.sh
  if [ "$has_bin_sh" = "yes" ]; then
    mkdir -p "$dir/bin"
    printf '#!/usr/bin/env bash\necho hello\n' > "$dir/bin/do-something.sh"
    chmod 755 "$dir/bin/do-something.sh"
  fi

  # tests/run.sh
  if [ "$has_tests" = "yes" ]; then
    mkdir -p "$dir/tests"
    printf '#!/usr/bin/env bash\necho ok\n' > "$dir/tests/run.sh"
    chmod 755 "$dir/tests/run.sh"
  fi
}

# ------------------------------------------------------------------
# 正例:完全合规的 skill(有 bin 有 tests)
# ------------------------------------------------------------------
echo "== 正例:合规 skill =="
mk_skill "good-skill" "good-skill" yes yes yes yes
assert 0 "合规 skill 通过(exit 0)" bash "$LINT" "$TMP/good-skill"

# 正例:无 bin 目录(不需要 tests)
echo "== 正例:无 bin 目录 =="
mk_skill "no-bin-skill" "no-bin-skill" yes yes no no
assert 0 "无 bin 目录的 skill 通过" bash "$LINT" "$TMP/no-bin-skill"

# ------------------------------------------------------------------
# 反例 1:缺 README.md
# ------------------------------------------------------------------
echo "== 反例:缺 README.md =="
mk_skill "no-readme" "no-readme" no yes no no
assert 2 "缺 README.md 报 exit 2" bash "$LINT" "$TMP/no-readme"

# ------------------------------------------------------------------
# 反例 2:frontmatter name 与目录名不一致
# ------------------------------------------------------------------
echo "== 反例:name 与目录名不一致 =="
mk_skill "dir-name" "wrong-name" yes yes no no
assert 2 "name 不匹配目录名报 exit 2" bash "$LINT" "$TMP/dir-name"

# ------------------------------------------------------------------
# 反例 3:有 bin/*.sh 但无 tests/run.sh
# ------------------------------------------------------------------
echo "== 反例:有 bin 无 tests =="
mk_skill "bin-no-tests" "bin-no-tests" yes yes yes no
assert 2 "有 bin 无 tests 报 exit 2" bash "$LINT" "$TMP/bin-no-tests"

# ------------------------------------------------------------------
# 反例 4:缺 SKILL.md
# ------------------------------------------------------------------
echo "== 反例:缺 SKILL.md =="
mkdir -p "$TMP/no-skillmd"
printf '# no-skillmd\n[![x](https://img.shields.io/x)](http://x)\n' > "$TMP/no-skillmd/README.md"
assert 2 "缺 SKILL.md 报 exit 2" bash "$LINT" "$TMP/no-skillmd"

# ------------------------------------------------------------------
# 反例 5:README.md 无徽章
# ------------------------------------------------------------------
echo "== 反例:README 无徽章 =="
mk_skill "no-badge" "no-badge" yes no no no
assert 2 "README 无徽章报 exit 2" bash "$LINT" "$TMP/no-badge"

# ------------------------------------------------------------------
# 反例 6:SKILL.md 缺 frontmatter
# ------------------------------------------------------------------
echo "== 反例:SKILL.md 缺 frontmatter =="
mkdir -p "$TMP/no-fm"
printf '# no-fm\n没有 frontmatter。\n' > "$TMP/no-fm/SKILL.md"
printf '# no-fm\n[![x](https://img.shields.io/x)](http://x)\n' > "$TMP/no-fm/README.md"
assert 2 "缺 frontmatter 报 exit 2" bash "$LINT" "$TMP/no-fm"

# ------------------------------------------------------------------
# 结果汇总
# ------------------------------------------------------------------
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
