#!/usr/bin/env bash
# collect-commits.sh — 收集某区间的提交,按 conventional 类型归类(确定性,供 Claude 润色成中文 changelog)
# 用法:
#   collect-commits.sh [from] [to]
#     from 缺省 = 最近一个 tag(无 tag 则从根提交);to 缺省 = HEAD
#     例:collect-commits.sh v1.2.0 HEAD
# 输出:RANGE 行 + 各类型分组(### feat / ### fix ...),含每条 subject;末尾 OTHER 收非规范提交
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: 不在 git 仓库内" >&2; exit 1; }

from="${1:-}"; to="${2:-HEAD}"
if [ -z "$from" ]; then
  from="$(git describe --tags --abbrev=0 2>/dev/null || echo '')"
fi
if [ -n "$from" ]; then range="$from..$to"; else range="$to"; fi

echo "RANGE: ${from:-<root>}..$to"

# 已知 conventional 类型(顺序即 changelog 展示顺序)
types="feat fix perf refactor docs test build ci chore revert"

# 收集 subject(去掉 merge 提交)
subjects="$(git log --no-merges --pretty='%s' $range 2>/dev/null)"

emit_group() {
  local t="$1"
  # 匹配 "type:" 或 "type(scope):",大小写不敏感
  local lines
  lines="$(printf '%s\n' "$subjects" | grep -iE "^${t}(\([^)]*\))?!?:" || true)"
  [ -z "$lines" ] && return
  echo ""
  echo "### $t (×$(printf '%s\n' "$lines" | grep -c .))"
  printf '%s\n' "$lines" | sed -E "s/^[^:]*:[[:space:]]*//; s/^/- /"
}

for t in $types; do emit_group "$t"; done

# 非规范提交(不匹配任何已知类型前缀)
known_rx="^($(echo "$types" | tr ' ' '|'))(\([^)]*\))?!?:"
other="$(printf '%s\n' "$subjects" | grep -ivE "$known_rx" | grep -v '^[[:space:]]*$' || true)"
if [ -n "$other" ]; then
  echo ""
  echo "### other (×$(printf '%s\n' "$other" | grep -c .))"
  printf '%s\n' "$other" | sed 's/^/- /'
fi
