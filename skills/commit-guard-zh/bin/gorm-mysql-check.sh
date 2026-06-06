#!/usr/bin/env bash
# gorm-mysql-check — 扫暂存的 *.go,揪 GORM × MySQL 非法写法(命中 exit 2)
# 最常见坑:TEXT/BLOB/JSON 列带 DEFAULT → MySQL Error 1101,迁移直接炸。
# 默认关闭,在 .commit-guard.sh 里设 ENABLE_GORM_CHECK=1 启用。
# 用法:
#   gorm-mysql-check.sh              扫 git diff --cached 的新增 .go 行
#   gorm-mysql-check.sh <文件>        扫指定文件内容(测试用)
set -uo pipefail

# 取暂存 .go 的新增行(带文件名前缀),或测试时直接读文件
collect() {
  if [ "${1:-}" != "" ]; then awk '{print FILENAME":"FNR": "$0}' "$1"; return; fi
  for f in $(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.go$' || true); do
    git diff --cached --unified=0 -- "$f" 2>/dev/null \
      | grep -E '^\+' | grep -Ev '^\+\+\+' | sed "s|^+|$f: |"
  done
}

input="$(collect "${1:-}")"
[ -z "$input" ] && exit 0

# GORM tag 里 TEXT/BLOB/(LONG)TEXT/JSON 列同时带 default: → 非法
# 例:`gorm:"type:text;default:''"` / `type:json;default:'{}'`
rx='gorm:"[^"]*type:[[:space:]]*(long|medium|tiny)?(text|blob|json)[^"]*default:'
hits="$(printf '%s\n' "$input" | grep -niE "$rx" || true)"

if [ -n "$hits" ]; then
  echo "🚫 [gorm-mysql-check] GORM 模型里 TEXT/BLOB/JSON 列带了 DEFAULT —— MySQL 会报 Error 1101,迁移会断:" >&2
  printf '%s\n' "$hits" | sed 's/^/      /' >&2
  echo "" >&2
  echo "  → 修法:去掉该列的 default(用代码层赋默认值),或把列类型改成可带默认的(如 varchar)。" >&2
  exit 2
fi
exit 0
