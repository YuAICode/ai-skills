#!/usr/bin/env bash
# secret-scan — 扫 staged diff 里的密钥/凭据,命中即拦(exit 2)
# 用法:
#   secret-scan.sh                 扫 git diff --cached(默认)
#   secret-scan.sh <diff文件>       扫指定 diff 文件(测试用)
# 退出码:0=干净 / 2=发现疑似密钥
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
# 可选 config:目标 repo 根下 .commit-guard.sh 可定义 SECRET_WHITELIST(extended regex)
SECRET_WHITELIST="${SECRET_WHITELIST:-}"
[ -f "$REPO_ROOT/.commit-guard.sh" ] && . "$REPO_ROOT/.commit-guard.sh" 2>/dev/null || true

# 取"新增行"(diff 里以 + 开头、排除 +++ 头)
added_lines() {
  if [ "${1:-}" != "" ]; then cat "$1"; else git diff --cached --unified=0 2>/dev/null; fi \
    | grep -E '^\+' | grep -Ev '^\+\+\+'
}

# 规则:描述|extended-regex
RULES=(
  "私钥块 (PRIVATE KEY)|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----"
  "AWS Access Key|AKIA[0-9A-Z]{16}"
  "Slack token|xox[baprs]-[0-9A-Za-z-]{10,}"
  "GitHub token|gh[pousr]_[0-9A-Za-z]{30,}"
  "Google/Firebase API key|AIza[0-9A-Za-z_-]{35}"
  "Firebase service-account JSON|\"type\"[[:space:]]*:[[:space:]]*\"service_account\""
  "私钥字段 private_key|\"private_key\"[[:space:]]*:"
  "通用密钥赋值|(api[_-]?key|secret|token|password|passwd|pwd|access[_-]?token)[\"' ]*[:=][\"' ]*[^\"'[:space:]]{16,}"
)

input="$(added_lines "${1:-}")"
hits=0
while IFS='|' read -r desc rx; do
  [ -z "$desc" ] && continue
  matched="$(printf '%s\n' "$input" | grep -niE -e "$rx" || true)"
  [ -z "$matched" ] && continue
  # 白名单豁免
  if [ -n "$SECRET_WHITELIST" ]; then
    matched="$(printf '%s\n' "$matched" | grep -Ev -e "$SECRET_WHITELIST" || true)"
    [ -z "$matched" ] && continue
  fi
  if [ "$hits" -eq 0 ]; then
    echo "🚫 [secret-scan] 暂存改动里发现疑似密钥/凭据,已拦截:" >&2
  fi
  echo "  • ${desc}:" >&2
  printf '%s\n' "$matched" | sed 's/^/      /' >&2
  hits=$((hits+1))
done < <(printf '%s\n' "${RULES[@]}")

# .p8 / 明显凭据文件名(看新增文件路径)
if [ "${1:-}" = "" ]; then
  newfiles="$(git diff --cached --name-only --diff-filter=A 2>/dev/null || true)"
  badfiles="$(printf '%s\n' "$newfiles" | grep -iE '\.(p8|pem|key)$|service-account.*\.json|google-services\.json|GoogleService-Info\.plist' || true)"
  if [ -n "$badfiles" ]; then
    [ "$hits" -eq 0 ] && echo "🚫 [secret-scan] 暂存改动里发现疑似密钥/凭据,已拦截:" >&2
    echo "  • 新增凭据类文件:" >&2
    printf '%s\n' "$badfiles" | sed 's/^/      /' >&2
    hits=$((hits+1))
  fi
fi

if [ "$hits" -gt 0 ]; then
  echo "" >&2
  echo "  → 确认要提交?把它移出暂存(git restore --staged <file>),或加进 .gitignore," >&2
  echo "    误报可在 .commit-guard.sh 里设 SECRET_WHITELIST='正则' 豁免。" >&2
  exit 2
fi
exit 0
