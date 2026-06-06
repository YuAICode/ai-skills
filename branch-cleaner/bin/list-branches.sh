#!/usr/bin/env bash
# list-branches.sh — 列出可清理的本地分支(已合并 / 陈旧),供用户确认后再删。
# 用法:
#   list-branches.sh [protect_branches...] [stale_days]
#     protect_branches  额外保护分支(空格分隔字符串,默认保护 main master + 当前分支)
#     stale_days        陈旧判定天数(整数,默认 60)
# 环境变量:
#   BRANCH_PROTECT_EXTRA  同 protect_branches(测试时覆盖)
#   STALE_DAYS            同 stale_days(测试时覆盖)
# 输出:
#   MERGED: 已合并进默认分支的本地分支(每行 <branch>  <最后提交日期>)
#   STALE:  最后提交早于 N 天的本地分支(每行 <branch>  <最后提交日期>)
#   注:两组均不含受保护分支;STALE 中已在 MERGED 的分支会重复显示(都可删)。
set -uo pipefail

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: 不在 git 仓库内" >&2; exit 1; }

# ---- 参数解析 ----
# 最后一个纯数字参数视为 stale_days;其余全是额外保护分支
extra_protect="${BRANCH_PROTECT_EXTRA:-}"
stale_days="${STALE_DAYS:-60}"

args=("$@")
if [ "${#args[@]}" -gt 0 ]; then
  last="${args[${#args[@]}-1]}"
  if printf '%s' "$last" | grep -qE '^[0-9]+$'; then
    stale_days="$last"
    extra_protect="${args[*]::${#args[@]}-1}"
  else
    extra_protect="${args[*]}"
  fi
fi

# ---- 确定当前分支与保护集 ----
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
# 注:HEAD detached 时 current_branch = "HEAD",不会误匹配任何分支名

# 判断默认分支(main 优先,退而求 master,再退而求 origin/HEAD)
default_branch=""
for b in main master; do
  if git show-ref --verify --quiet "refs/heads/$b"; then
    default_branch="$b"; break
  fi
done
if [ -z "$default_branch" ]; then
  # 尝试 origin/HEAD 的映射
  default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#refs/remotes/origin/##' || echo '')"
fi

# 固定保护分支(不含空串)
protect_set="main master ${extra_protect}"
[ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ] && protect_set="$protect_set $current_branch"
[ -n "$default_branch" ] && protect_set="$protect_set $default_branch"

is_protected() {
  local b="$1"
  for p in $protect_set; do
    [ "$b" = "$p" ] && return 0
  done
  return 1
}

# ---- 计算截止时间戳(距今 stale_days 天) ----
cutoff_ts=$(( $(date +%s) - stale_days * 86400 ))

# ---- 列出所有本地分支 ----
all_branches=()
while IFS= read -r br; do
  br="$(printf '%s' "$br" | sed 's/^[[:space:]]*//' | sed 's/^\* //')"
  [ -z "$br" ] && continue
  all_branches+=("$br")
done < <(git branch)

# ---- MERGED 组:已合并进默认分支的本地分支 ----
merged_branches=()
if [ -n "$default_branch" ]; then
  while IFS= read -r br; do
    br="$(printf '%s' "$br" | sed 's/^[[:space:]]*//' | sed 's/^\* //')"
    [ -z "$br" ] && continue
    is_protected "$br" && continue
    merged_branches+=("$br")
  done < <(git branch --merged "$default_branch")
fi

# ---- STALE 组:最后提交早于 N 天的分支(剔除保护分支) ----
stale_branches=()
for br in "${all_branches[@]}"; do
  is_protected "$br" && continue
  # committerdate 秒级时间戳
  commit_ts="$(git for-each-ref --format='%(committerdate:unix)' "refs/heads/${br}" 2>/dev/null)"
  [ -z "$commit_ts" ] && continue
  if [ "$commit_ts" -le "$cutoff_ts" ]; then
    stale_branches+=("$br")
  fi
done

# ---- 获取最后提交日期辅助函数 ----
branch_date() {
  git for-each-ref --format='%(committerdate:short)' "refs/heads/${1}" 2>/dev/null || echo "unknown"
}

# ---- 输出 ----
echo "MERGED: (已合并进 ${default_branch:-<无默认分支>} 的本地分支,可用 git branch -d 删除)"
if [ "${#merged_branches[@]}" -eq 0 ]; then
  echo "  (无)"
else
  for br in "${merged_branches[@]}"; do
    printf "  %-40s  %s\n" "$br" "$(branch_date "$br")"
  done
fi

echo ""
echo "STALE: (最后提交早于 ${stale_days} 天的本地分支,强删需 git branch -D)"
if [ "${#stale_branches[@]}" -eq 0 ]; then
  echo "  (无)"
else
  for br in "${stale_branches[@]}"; do
    printf "  %-40s  %s\n" "$br" "$(branch_date "$br")"
  done
fi

echo ""
echo "保护分支(不会列入候选):$(echo "$protect_set" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
