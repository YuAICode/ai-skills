#!/usr/bin/env bash
# collect-activity.sh — 采集 git 活动素材,供 Claude 生成中文日报/周报
# 用法:
#   collect-activity.sh [since] [author]
#     since  缺省 "1 day ago"(支持 "1 week ago" / "2024-06-01" 等 git 认识的格式)
#     author 缺省 当前 git user.email
# 输出:RANGE / AUTHOR 头 + 提交列表 + 改动文件统计
# 只读 git,不做任何写操作。
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: 不在 git 仓库内" >&2; exit 1; }

since="${1:-1 day ago}"
author="${2:-}"
if [ -z "$author" ]; then
  author="$(git config user.email 2>/dev/null || true)"
  if [ -z "$author" ]; then
    echo "ERROR: 无法取得 git user.email,请显式传入 author 参数" >&2
    exit 1
  fi
fi

echo "RANGE: since '$since'"
echo "AUTHOR: $author"
echo ""

echo "COMMITS:"
git log \
  --author="$author" \
  --since="$since" \
  --no-merges \
  --pretty="format:- [%h] %ad %s" \
  --date=short \
  2>/dev/null
echo ""

echo "STATS:"
# Collect shortstat lines; grep -v may return exit 1 when output is empty — suppress with || true
stat_lines="$(git log \
  --author="$author" \
  --since="$since" \
  --no-merges \
  --pretty=format: \
  --shortstat \
  2>/dev/null | grep -v '^[[:space:]]*$' || true)"
printf '%s\n' "$stat_lines" | \
  awk '
    /[0-9]+ file/ {
      files += $1
      for (i=1; i<=NF; i++) {
        if ($i == "insertions(+)," || $i == "insertion(+),") ins += $(i-1)
        if ($i == "insertions(+)"  || $i == "insertion(+)")  ins += $(i-1)
        if ($i == "deletions(-)"   || $i == "deletion(-)")   del += $(i-1)
      }
    }
    END {
      if (files > 0)
        printf "共变动 %d 个文件,+%d / -%d 行\n", files, ins, del
      else
        print "(该区间无改动)"
    }
  '
