#!/usr/bin/env bash
# collect.sh — 采集指定文件的 git 修改历史素材,供 Claude 叙述成故事
# 用法:
#   collect.sh <文件路径>
# 输出:META / COMMITS / CONTRIBUTORS / TIMELINE / CHURN 五段纯文本
# 只读 git,不做任何写操作。bash 3.2 兼容。
set -uo pipefail

# ---- 参数检验 ----
if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "ERROR: 请传入文件路径。用法:collect.sh <文件路径>" >&2
  exit 1
fi

FILE="$1"

# ---- git 仓库检验 ----
git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: 不在 git 仓库内" >&2; exit 1; }

# ---- 文件存在性检验(允许已删除但有历史的文件跳过) ----
# 先查 git 历史中有没有该文件记录
commit_count="$(git log --follow --oneline -- "$FILE" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$commit_count" -eq 0 ]; then
  if [ ! -e "$FILE" ]; then
    echo "ERROR: 文件不存在:$FILE" >&2
  else
    echo "ERROR: 文件不在 git 追踪范围内:$FILE" >&2
  fi
  exit 1
fi

repo_name="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")"
collect_time="$(date '+%Y-%m-%d %H:%M:%S')"

# ---- META ----
echo "META:"
echo "  file:         $FILE"
echo "  repo:         $repo_name"
echo "  collect_time: $collect_time"
echo "  total_commits: $commit_count"
echo ""

# ---- COMMITS ----
# 格式:hash|author|date|subject  (含 --follow 追踪重命名)
echo "COMMITS:"
commit_lines="$(git log --follow --pretty='format:%h|%an|%ad|%s' --date=short -- "$FILE" 2>/dev/null || true)"
if [ -z "$commit_lines" ]; then
  echo "  (无提交记录)"
else
  printf '%s\n' "$commit_lines" | while IFS='|' read -r hash author date subject; do
    echo "  [$hash] $date | $author | $subject"
  done
fi
echo ""

# ---- CONTRIBUTORS ----
# 贡献者按提交数降序排列
echo "CONTRIBUTORS:"
contrib="$(git log --follow --pretty='format:%an' -- "$FILE" 2>/dev/null \
  | sort | uniq -c | sort -rn || true)"
if [ -z "$contrib" ]; then
  echo "  (无数据)"
else
  printf '%s\n' "$contrib" | while read -r cnt name; do
    echo "  $cnt 次提交  $name"
  done
fi
echo ""

# ---- TIMELINE ----
# 首次提交与最近提交
echo "TIMELINE:"
# 最近提交(log 默认从新到旧,head -1)
latest_line="$(git log --follow --pretty='format:%h|%an|%ad|%s' --date=short -- "$FILE" 2>/dev/null | head -1 || true)"
# 首次提交(tail -1)
first_line="$(git log --follow --pretty='format:%h|%an|%ad|%s' --date=short -- "$FILE" 2>/dev/null | tail -1 || true)"

if [ -n "$first_line" ]; then
  first_hash="$(printf '%s' "$first_line" | cut -d'|' -f1)"
  first_author="$(printf '%s' "$first_line" | cut -d'|' -f2)"
  first_date="$(printf '%s' "$first_line" | cut -d'|' -f3)"
  first_subject="$(printf '%s' "$first_line" | cut -d'|' -f4)"
  echo "  首次提交: [$first_hash] $first_date | $first_author | $first_subject"
fi
if [ -n "$latest_line" ]; then
  latest_hash="$(printf '%s' "$latest_line" | cut -d'|' -f1)"
  latest_author="$(printf '%s' "$latest_line" | cut -d'|' -f2)"
  latest_date="$(printf '%s' "$latest_line" | cut -d'|' -f3)"
  latest_subject="$(printf '%s' "$latest_line" | cut -d'|' -f4)"
  echo "  最近提交: [$latest_hash] $latest_date | $latest_author | $latest_subject"
fi
echo ""

# ---- CHURN ----
# 近期 5 次提交的增删行数趋势
echo "CHURN (近期最多5次提交):"
recent_hashes="$(git log --follow --pretty='format:%h' -- "$FILE" 2>/dev/null | head -5 || true)"
if [ -z "$recent_hashes" ]; then
  echo "  (无数据)"
else
  printf '%s\n' "$recent_hashes" | while read -r h; do
    stat_line="$(git show --stat --format='' "$h" -- "$FILE" 2>/dev/null | grep -E 'insertion|deletion' | head -1 || true)"
    date_sub="$(git log -1 --pretty='format:%ad|%s' --date=short "$h" 2>/dev/null || true)"
    d="$(printf '%s' "$date_sub" | cut -d'|' -f1)"
    s="$(printf '%s' "$date_sub" | cut -d'|' -f2)"
    if [ -n "$stat_line" ]; then
      echo "  [$h] $d | $s | $stat_line"
    else
      echo "  [$h] $d | $s | (无行级改动记录)"
    fi
  done
fi
