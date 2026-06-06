#!/usr/bin/env bash
# collect.sh — 采集生成 PR 描述所需的素材(确定性,供 Claude 消费)
# 用法:
#   collect.sh [base]
#     base 缺省时自动探测默认分支(origin/HEAD → origin/main → main ...)
# 输出:BASE / COMMITS / FILES / DIFFSTAT 四段纯文本
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: 不在 git 仓库内" >&2; exit 1; }

base="${1:-}"
if [ -z "$base" ]; then
  base="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@')"
  if [ -z "$base" ]; then
    for b in origin/main origin/master origin/develop main master develop; do
      git rev-parse --verify "$b" >/dev/null 2>&1 && { base="$b"; break; }
    done
  fi
fi
[ -z "$base" ] && { echo "ERROR: 无法确定 base 分支,请显式传入" >&2; exit 1; }

# 当前分支与 base 的最近公共祖先,避免把 base 自己的提交也算进来
mb="$(git merge-base "$base" HEAD 2>/dev/null || echo "$base")"
range="$mb..HEAD"

echo "BASE: $base"
echo "HEAD: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
echo ""
echo "COMMITS:"
git log --pretty='- %s' "$range" 2>/dev/null
echo ""
echo "FILES:"
git diff --name-status "$range" 2>/dev/null
echo ""
echo "DIFFSTAT:"
git diff --stat "$range" 2>/dev/null
