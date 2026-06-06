#!/usr/bin/env bash
# collect.sh — 采集 git 提交历史素材,供 Claude 进行中文吐槽
# 用法:
#   collect.sh [数量] [author]
#     数量   缺省 30(最近 N 条提交)
#     author 缺省 空(全部作者);支持邮箱或姓名子串,传给 git --author
# 输出:META / COMMITS / SHORTSTATS / SUMMARY 四段纯文本
# 只读 git,不做任何写操作。bash 3.2 兼容。
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: 不在 git 仓库内" >&2; exit 1; }

count="${1:-30}"
author="${2:-}"

# 校验 count 为正整数
case "$count" in
  ''|*[!0-9]*) echo "ERROR: 数量参数须为正整数,收到:$count" >&2; exit 1;;
esac
[ "$count" -gt 0 ] || { echo "ERROR: 数量须大于 0" >&2; exit 1; }

repo_name="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")"
collect_time="$(date '+%Y-%m-%d %H:%M:%S')"

# --- META ---
echo "META:"
echo "  repo:         $repo_name"
echo "  collect_time: $collect_time"
echo "  count:        $count"
if [ -n "$author" ]; then
  echo "  author:       $author"
else
  echo "  author:       (全部)"
fi
echo ""

# --- 构造 git log 参数 ---
author_arg=""
if [ -n "$author" ]; then
  author_arg="--author=$author"
fi

# 取提交列表:hash + ISO日期时间 + subject,用分隔符拼在一行
# 格式: <hash>|<datetime>|<subject>
if [ -n "$author_arg" ]; then
  commit_lines="$(git log --no-merges -n "$count" "$author_arg" \
    --pretty='format:%h|%ci|%s' 2>/dev/null || true)"
else
  commit_lines="$(git log --no-merges -n "$count" \
    --pretty='format:%h|%ci|%s' 2>/dev/null || true)"
fi

echo "COMMITS:"
if [ -z "$commit_lines" ]; then
  echo "  (无提交记录)"
else
  printf '%s\n' "$commit_lines" | while IFS='|' read -r hash dt subject; do
    echo "  [$hash] $dt | $subject"
  done
fi
echo ""

# --- SHORTSTATS:每条提交的增删统计 ---
# 遍历同一组 hash,取 --shortstat
echo "SHORTSTATS:"
if [ -z "$commit_lines" ]; then
  echo "  (无数据)"
else
  total_ins=0
  total_del=0
  total_commits=0

  printf '%s\n' "$commit_lines" | while IFS='|' read -r hash dt subject; do
    stat="$(git show --stat --format='' "$hash" 2>/dev/null | tail -1 | \
      grep -E '[0-9]+ file' || echo "(无文件改动)")"
    echo "  [$hash] $stat"
  done

  # 总计:单独再跑一次取数字(while 子 shell 无法带出变量)
  all_hashes="$(printf '%s\n' "$commit_lines" | cut -d'|' -f1 | tr '\n' ' ')"
  total_ins=0; total_del=0; total_commits=0
  for h in $all_hashes; do
    total_commits=$((total_commits+1))
    nums="$(git show --stat --format='' "$h" 2>/dev/null | tail -1)"
    ins="$(printf '%s' "$nums" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)"
    del="$(printf '%s' "$nums" | grep -oE '[0-9]+ deletion'  | grep -oE '[0-9]+' || echo 0)"
    [ -z "$ins" ] && ins=0
    [ -z "$del" ] && del=0
    total_ins=$((total_ins+ins))
    total_del=$((total_del+del))
  done

  echo ""
  echo "SUMMARY:"
  echo "  total_commits: $total_commits"
  echo "  total_ins:     +$total_ins"
  echo "  total_del:     -$total_del"
fi
