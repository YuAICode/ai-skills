#!/usr/bin/env bash
# git-undo/bin/state.sh — 采集当前 git 状态供 Claude 判断
# 纯只读，不执行任何写操作。
# 用法：bash state.sh [git-repo-path]
#   可选参数：指定 git 仓库路径，默认当前目录
# 兼容 bash 3.2+，无外部依赖。
set -uo pipefail

# 目标目录（支持传参）
TARGET="${1:-.}"

# 检查是否在 git 仓库内
if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "【错误】当前目录不在 git 仓库内：$TARGET"
  exit 1
fi

SEP="────────────────────────────"

# ---- 当前分支 ----
branch="$(git -C "$TARGET" symbolic-ref --short HEAD 2>/dev/null || git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || echo "(无法确定)")"
echo "## 当前分支"
echo "$branch"
echo ""

# ---- 工作区状态 ----
echo "## 工作区状态（git status -s）"
status_out="$(git -C "$TARGET" status -s 2>/dev/null)"
if [ -z "$status_out" ]; then
  echo "（干净，无未提交/未暂存改动）"
else
  echo "$status_out"
fi
echo ""

# ---- 未暂存/未提交标志 ----
echo "## 状态摘要"
# 未暂存改动（已跟踪文件在工作区有修改）
if git -C "$TARGET" diff --quiet 2>/dev/null; then
  echo "未暂存改动: 无"
else
  echo "未暂存改动: 有"
fi
# 未提交改动（暂存区有内容）
if git -C "$TARGET" diff --cached --quiet 2>/dev/null; then
  echo "未提交改动（暂存区）: 无"
else
  echo "未提交改动（暂存区）: 有"
fi
# 未跟踪文件
untracked="$(git -C "$TARGET" ls-files --others --exclude-standard 2>/dev/null | head -5)"
if [ -n "$untracked" ]; then
  echo "未跟踪文件: 有（前5条）"
  # 逐行输出，避免空格分词问题
  while IFS= read -r line; do
    echo "  $line"
  done <<EOF
$untracked
EOF
else
  echo "未跟踪文件: 无"
fi
echo ""

# ---- 最近 5 条提交 ----
echo "## 最近 5 条提交（git log --oneline）"
log_out="$(git -C "$TARGET" log --oneline -5 2>/dev/null)"
if [ -z "$log_out" ]; then
  echo "（暂无提交）"
else
  echo "$log_out"
fi
echo ""

# ---- reflog 最近 10 条 ----
echo "## reflog 最近 10 条"
reflog_out="$(git -C "$TARGET" reflog --oneline -10 2>/dev/null)"
if [ -z "$reflog_out" ]; then
  echo "（暂无 reflog 记录）"
else
  echo "$reflog_out"
fi
echo ""

# ---- 上游信息 ----
echo "## 上游分支信息"
upstream="$(git -C "$TARGET" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || echo "")"
if [ -z "$upstream" ]; then
  echo "上游分支: 无（本地分支，尚未设置 upstream）"
else
  echo "上游分支: $upstream"
  # 领先/落后
  ahead_behind="$(git -C "$TARGET" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo "")"
  if [ -n "$ahead_behind" ]; then
    behind="$(printf '%s' "$ahead_behind" | awk '{print $1}')"
    ahead="$(printf '%s' "$ahead_behind" | awk '{print $2}')"
    echo "本地领先上游: ${ahead} 条提交"
    echo "本地落后上游: ${behind} 条提交"
  fi
fi
echo ""

echo "$SEP"
echo "（以上均为只读采集，未执行任何写操作）"
