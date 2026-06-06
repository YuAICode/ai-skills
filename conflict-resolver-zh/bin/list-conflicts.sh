#!/usr/bin/env bash
# list-conflicts.sh — 列出目录中含 git 冲突标记的文件及冲突块内容
# 用法:
#   list-conflicts.sh [目录,默认当前目录]
# 退出码:
#   0 — 成功执行(无论有无冲突)
# 输出:
#   无冲突时打印"无冲突"
#   有冲突时打印每个文件的冲突块行号 + ours/theirs 内容
set -uo pipefail

TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo "目录不存在或无法访问:$1" >&2; exit 1; }

# ---- 找冲突文件 ----
# 优先:git diff --name-only --diff-filter=U(仅当处于 git 仓库且 git 可用)
conflict_files=""
use_git=0
if command -v git >/dev/null 2>&1 && git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  use_git=1
  conflict_files="$(git -C "$TARGET" diff --name-only --diff-filter=U 2>/dev/null || true)"
  # 把相对路径补全为绝对路径
  if [ -n "$conflict_files" ]; then
    abs_files=""
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      abs_files="$abs_files
$TARGET/$f"
    done <<EOF
$conflict_files
EOF
    conflict_files="$(printf '%s\n' "$abs_files" | grep -v '^$' || true)"
  fi
fi

# 退而求其次:grep 扫描目录内所有普通文件
if [ -z "$conflict_files" ]; then
  conflict_files="$(grep -rl '^<<<<<<< ' "$TARGET" 2>/dev/null || true)"
fi

if [ -z "$conflict_files" ]; then
  echo "无冲突"
  exit 0
fi

# ---- 对每个文件提取冲突块 ----
# 输出格式:
#   === 文件: <路径> ===
#   --- 冲突块 #N (行 <起始>–<结束>) ---
#   [ours / 当前分支]
#   <内容,带行号>
#   [theirs / 传入分支]
#   <内容,带行号>

total_conflicts=0

while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue
  [ -f "$filepath" ] || continue

  echo ""
  echo "=== 文件: $filepath ==="

  block_num=0
  in_ours=0
  in_theirs=0
  ours_lines=""
  theirs_lines=""
  block_start=0
  block_end=0
  lineno=0

  # 逐行扫描文件
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    case "$line" in
      '<<<<<<<'*)
        in_ours=1
        in_theirs=0
        ours_lines=""
        theirs_lines=""
        block_start=$lineno
        ;;
      '======='*)
        if [ "$in_ours" = "1" ]; then
          in_ours=0
          in_theirs=1
        fi
        ;;
      '>>>>>>>'*)
        if [ "$in_theirs" = "1" ]; then
          in_theirs=0
          block_end=$lineno
          block_num=$((block_num + 1))
          total_conflicts=$((total_conflicts + 1))
          echo ""
          echo "--- 冲突块 #${block_num} (行 ${block_start}–${block_end}) ---"
          echo "[ours / 当前分支]"
          if [ -n "$ours_lines" ]; then
            printf '%s\n' "$ours_lines"
          else
            echo "  (空)"
          fi
          echo "[theirs / 传入分支]"
          if [ -n "$theirs_lines" ]; then
            printf '%s\n' "$theirs_lines"
          else
            echo "  (空)"
          fi
        fi
        ;;
      *)
        if [ "$in_ours" = "1" ]; then
          ours_lines="${ours_lines}
  ${lineno}: ${line}"
        elif [ "$in_theirs" = "1" ]; then
          theirs_lines="${theirs_lines}
  ${lineno}: ${line}"
        fi
        ;;
    esac
  done < "$filepath"

done <<EOF
$conflict_files
EOF

echo ""
if [ "$total_conflicts" -gt 0 ]; then
  echo "共发现 ${total_conflicts} 个冲突块,请逐一确认解决方式后再 git add。"
fi
exit 0
