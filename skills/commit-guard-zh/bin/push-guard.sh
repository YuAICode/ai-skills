#!/usr/bin/env bash
# push-guard — 推送前护栏:保护分支需确认 + 防把 env/密钥文件推上去
# 用法:
#   push-guard.sh [当前分支]
#     不传分支则自动取当前分支。
# 确认:推保护分支时,hook 模式需 COMMIT_GUARD_CONFIRM=1;否则 exit 2 中止。
# 退出码:0=放行 / 2=拦截
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
BRANCH_PROTECT="${BRANCH_PROTECT:-main master}"          # 可在 config 覆盖
[ -f "$REPO_ROOT/.commit-guard.sh" ] && . "$REPO_ROOT/.commit-guard.sh" 2>/dev/null || true

branch="${1:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')}"
hits=0

# 1) 保护分支确认
for b in $BRANCH_PROTECT; do
  if [ "$branch" = "$b" ]; then
    if [ "${COMMIT_GUARD_CONFIRM:-}" != "1" ]; then
      echo "🚫 [push-guard] 正在推送到受保护分支 '$branch'。" >&2
      echo "  → 确认无误再来:COMMIT_GUARD_CONFIRM=1 git push   (或走 PR)" >&2
      hits=$((hits+1))
    fi
  fi
done

# 2) 防 env / 密钥类文件被推上去(检查本地相对 @{u} 的待推提交;无上游则看最近一次提交)
range=""
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  range="@{u}..HEAD"
elif git rev-parse HEAD~1 >/dev/null 2>&1; then
  range="HEAD~1..HEAD"
else
  range="HEAD"
fi
pushed_files="$(git diff --name-only $range 2>/dev/null || true)"
leak="$(printf '%s\n' "$pushed_files" | grep -iE '(^|/)\.env(\..+)?$|\.(p8|pem|key)$|service-account.*\.json' || true)"
if [ -n "$leak" ]; then
  echo "🚫 [push-guard] 待推送的提交里包含 env/密钥类文件:" >&2
  printf '%s\n' "$leak" | sed 's/^/      /' >&2
  echo "  → 这些不该进仓库。git rm --cached 它们、加 .gitignore,改历史后再推。" >&2
  hits=$((hits+1))
fi

[ "$hits" -gt 0 ] && exit 2
exit 0
