#!/usr/bin/env bash
# check-readme-sync.sh — 核对 skills/ 目录 与 README.md / README.zh-CN.md 三方的 skill 列表一致。
# 以 skills/ 目录为准(ground truth)。任何一方缺/多/中英不一致 → 报错 exit 1。
# 用法:bash scripts/check-readme-sync.sh   (在仓库任意位置都可)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
fail=0

# ground truth:skills/ 下的目录名
ground="$(for d in skills/*/; do [ -d "$d" ] && basename "$d"; done | sort -u)"

# 从一个 README 提取它链接到的 skill(](./skills/<name>) 形式,去重)
extract() { grep -oE '\]\(\./skills/[a-z0-9-]+\)' "$1" 2>/dev/null | sed -E 's#\]\(\./skills/##; s#\)##' | sort -u; }
en="$(extract README.md)"
zh="$(extract README.zh-CN.md)"

report() { # <标签> <missing> <extra>
  local label="$1" missing="$2" extra="$3"
  if [ -n "$missing" ]; then
    printf "${RED}❌ %s 缺少(skills/ 里有但没列):${NC}\n" "$label"; printf '%s\n' "$missing" | sed 's/^/    /'; fail=1
  fi
  if [ -n "$extra" ]; then
    printf "${RED}❌ %s 多出(列了但 skills/ 里没有):${NC}\n" "$label"; printf '%s\n' "$extra" | sed 's/^/    /'; fail=1
  fi
}

# 各 README vs ground
report "README.md(英文)"      "$(comm -23 <(printf '%s\n' "$ground") <(printf '%s\n' "$en"))" "$(comm -13 <(printf '%s\n' "$ground") <(printf '%s\n' "$en"))"
report "README.zh-CN.md(中文)" "$(comm -23 <(printf '%s\n' "$ground") <(printf '%s\n' "$zh"))" "$(comm -13 <(printf '%s\n' "$ground") <(printf '%s\n' "$zh"))"

# 中英直接互比(即使都和 ground 一致,这步也能兜住描述错位之外的纯列表差异)
only_en="$(comm -23 <(printf '%s\n' "$en") <(printf '%s\n' "$zh"))"
only_zh="$(comm -13 <(printf '%s\n' "$en") <(printf '%s\n' "$zh"))"
if [ -n "$only_en" ]; then printf "${RED}❌ 只在英文 README 出现:${NC}\n"; printf '%s\n' "$only_en" | sed 's/^/    /'; fail=1; fi
if [ -n "$only_zh" ]; then printf "${RED}❌ 只在中文 README 出现:${NC}\n"; printf '%s\n' "$only_zh" | sed 's/^/    /'; fail=1; fi

n_ground=$(printf '%s\n' "$ground" | grep -c .)
if [ "$fail" = 0 ]; then
  printf "${GREEN}✅ 三方一致:%s 个 skill,中英 README 完全同步${NC}\n" "$n_ground"
else
  printf "${RED}核对未通过:加 skill 后请同时更新 README.md 与 README.zh-CN.md 的列表${NC}\n" >&2
fi
exit $fail
