#!/usr/bin/env bash
# gitignore-doctor/bin/check.sh — 揪出已被 git 追踪或未被忽略的垃圾文件
# 用法:
#   check.sh [项目目录]   默认当前目录
# 退出码:
#   0 = 干净(仅有"建议加进 .gitignore"或无问题)
#   2 = 发现已被追踪的垃圾文件(需 git rm --cached + 加 .gitignore)
set -uo pipefail

TARGET="${1:-}"
if [ -n "$TARGET" ]; then
  cd "$TARGET" || { echo "❌ 无法进入目录:$TARGET" >&2; exit 1; }
fi

# 确认在 git repo 里
git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "❌ 当前目录不是 git 仓库" >&2; exit 1
}

# ----------------------------------------------------------------
# 垃圾模式(路径前缀/后缀/精确 glob,不依赖 extglob)
# 格式:每行一条 extended-regex(用于 grep -E)
# ----------------------------------------------------------------
PATTERNS=(
  "(^|/)node_modules/"
  "(^|/)dist/"
  "(^|/)build/"
  "(^|/)\.env($|(\.[^/]+$))"
  "(^|/)\.DS_Store$"
  "\.log$"
  "(^|/)__pycache__/"
  "\.pyc$"
  "(^|/)\.idea/"
  "(^|/)\.vscode/"
  "(^|/)coverage/"
  "\.class$"
  "(^|/)target/"
  "(^|/)vendor/"
  "(^|/)\.gradle/"
  "(^|/)Pods/"
)

# 对应人类可读描述(与上面同序)
LABELS=(
  "node_modules/"
  "dist/"
  "build/"
  ".env / .env.*"
  ".DS_Store"
  "*.log"
  "__pycache__/"
  "*.pyc"
  ".idea/"
  ".vscode/"
  "coverage/"
  "*.class"
  "target/"
  "vendor/"
  ".gradle/"
  "Pods/"
)

# 对应建议追加到 .gitignore 的内容
SUGGESTIONS=(
  "node_modules/"
  "dist/"
  "build/"
  ".env"
  ".env.*"
  ".DS_Store"
  "*.log"
  "__pycache__/"
  "*.pyc"
  ".idea/"
  ".vscode/"
  "coverage/"
  "*.class"
  "target/"
  "vendor/"
  ".gradle/"
  "Pods/"
)

# ----------------------------------------------------------------
# 1. 已被追踪的垃圾(git ls-files 列出来的,命中任意模式)
# ----------------------------------------------------------------
tracked_hits=""  # 用换行拼接

all_tracked="$(git ls-files 2>/dev/null || true)"
if [ -n "$all_tracked" ]; then
  i=0
  while [ "$i" -lt "${#PATTERNS[@]}" ]; do
    pat="${PATTERNS[$i]}"
    label="${LABELS[$i]}"
    matched="$(printf '%s\n' "$all_tracked" | grep -E "$pat" || true)"
    if [ -n "$matched" ]; then
      # 每条文件拼上标签
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        tracked_hits="${tracked_hits}${f} [${label}]
"
      done <<_EOF
$matched
_EOF
    fi
    i=$((i+1))
  done
fi

# ----------------------------------------------------------------
# 2. 工作区里未被忽略、也未被追踪的垃圾(find + check-ignore)
# ----------------------------------------------------------------
# 收集工作区里(已追踪 + 未追踪)命中模式的文件
# 用 git status --porcelain 配合 find 取未追踪文件
untracked_hits=""

# 取所有工作区文件(未追踪 + 未忽略)
all_untracked="$(git ls-files --others --exclude-standard 2>/dev/null || true)"
if [ -n "$all_untracked" ]; then
  i=0
  while [ "$i" -lt "${#PATTERNS[@]}" ]; do
    pat="${PATTERNS[$i]}"
    label="${LABELS[$i]}"
    matched="$(printf '%s\n' "$all_untracked" | grep -E "$pat" || true)"
    if [ -n "$matched" ]; then
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        # 检查是否已被 .gitignore 忽略
        # git ls-files --others --exclude-standard 已经排除了被忽略的,
        # 所以命中的就是"未被忽略且未被追踪"的垃圾文件
        untracked_hits="${untracked_hits}${f} [${label}]
"
      done <<_EOF
$matched
_EOF
    fi
    i=$((i+1))
  done
fi

# ----------------------------------------------------------------
# 3. 输出报告
# ----------------------------------------------------------------

BOLD='\033[1m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━  gitignore-doctor 诊断报告  ━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- 已追踪垃圾 ---
if [ -n "$tracked_hits" ]; then
  printf "${RED}${BOLD}【已被 git 追踪的垃圾文件】(应执行 git rm --cached 并加入 .gitignore)${NC}\n"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf "  🗑  %s\n" "$line"
  done <<_EOF
$tracked_hits
_EOF
  echo ""
else
  printf "${GREEN}✓ 无已被追踪的垃圾文件${NC}\n\n"
fi

# --- 未忽略但未追踪的垃圾 ---
if [ -n "$untracked_hits" ]; then
  printf "${YELLOW}${BOLD}【建议加进 .gitignore 的文件】(当前未追踪但也未被忽略)${NC}\n"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    printf "  ⚠  %s\n" "$line"
  done <<_EOF
$untracked_hits
_EOF
  echo ""
else
  printf "${GREEN}✓ 工作区中无未被忽略的垃圾文件${NC}\n\n"
fi

# --- 建议追加到 .gitignore 的内容 ---
# 收集命中的模式去重后给出追加块
all_hits="${tracked_hits}${untracked_hits}"

if [ -n "$all_hits" ]; then
  echo "────────────────────────────────────────────────────────────────────────────"
  printf "${BOLD}【建议追加到 .gitignore 的内容】${NC}\n\n"
  printf '```\n'
  printf '# gitignore-doctor 建议追加\n'

  # 从命中文件名反查对应的 SUGGESTION 项(去重输出)
  printed=""
  i=0
  while [ "$i" -lt "${#PATTERNS[@]}" ]; do
    pat="${PATTERNS[$i]}"
    if printf '%s\n' "$all_hits" | grep -qE "$pat" 2>/dev/null; then
      # 找到命中,输出对应 suggestion
      sugg="${SUGGESTIONS[$i]}"
      # 同一 suggestion 可能对应多条 pattern,去重
      if ! printf '%s\n' "$printed" | grep -qxF "$sugg" 2>/dev/null; then
        printf '%s\n' "$sugg"
        printed="${printed}${sugg}
"
      fi
    fi
    i=$((i+1))
  done
  printf '```\n'
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 退出码
if [ -n "$tracked_hits" ]; then
  exit 2
fi
exit 0
