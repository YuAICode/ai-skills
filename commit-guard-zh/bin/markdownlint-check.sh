#!/usr/bin/env bash
# markdownlint-check — 对暂存的 *.md 跑 markdownlint(命中 exit 2)
# 默认关,在 .commit-guard.sh 设 ENABLE_MD_LINT=1 启用。
# 依赖 markdownlint-cli / markdownlint-cli2(任一);都没装则跳过(exit 0,不阻断工具链)。
# 可用 MD_LINT_CMD 指定自定义 linter 命令(测试 / 自定义用)。
# 用法:
#   markdownlint-check.sh                暂存的 .md
#   markdownlint-check.sh <file...>       指定文件(测试用)
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
[ -f "$REPO_ROOT/.commit-guard.sh" ] && . "$REPO_ROOT/.commit-guard.sh" 2>/dev/null || true

# 收集要检查的 md 文件
files=()
if [ "${1:-}" != "" ]; then
  files=("$@")
else
  while IFS= read -r f; do
    [ -n "$f" ] && files+=("$f")
  done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -iE '\.(md|markdown)$' || true)
fi
[ "${#files[@]}" -eq 0 ] && exit 0

# 选 linter:MD_LINT_CMD 覆盖 > markdownlint > markdownlint-cli2 > npx
runner=""
if [ -n "${MD_LINT_CMD:-}" ]; then
  runner="$MD_LINT_CMD"
elif command -v markdownlint >/dev/null 2>&1; then
  runner="markdownlint"
elif command -v markdownlint-cli2 >/dev/null 2>&1; then
  runner="markdownlint-cli2"
elif command -v npx >/dev/null 2>&1 && npx --no-install markdownlint --version >/dev/null 2>&1; then
  runner="npx --no-install markdownlint"
fi

if [ -z "$runner" ]; then
  echo "ℹ️  [markdownlint] 未检测到 markdownlint-cli,跳过 Markdown 检查。" >&2
  echo "   (装上即生效:npm i -g markdownlint-cli)" >&2
  exit 0
fi

out="$($runner "${files[@]}" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  echo "🚫 [markdownlint] 暂存的 Markdown 有 lint 问题:" >&2
  printf '%s\n' "$out" | sed 's/^/      /' >&2
  echo "" >&2
  echo "  → 修掉上面的问题;markdownlint --fix <file> 可自动修一部分,或在 .markdownlint.json 调规则。" >&2
  exit 2
fi
exit 0
