#!/usr/bin/env bash
# cron-regex-buddy 测试:对 bin/validate.sh 喂正例/反例,断言退出码与中文输出。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin/validate.sh"

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# assert <期望退出码> "<测试名>" -- <命令...>
assert() {
  local want="$1" name="$2"; shift 3
  local got
  bash "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 exit %s,实际 exit %s)${NC}\n" "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# 断言 stderr 包含指定子串
assert_stderr_contains() {
  local name="$1" pattern="$2"; shift 2
  local err
  err=$(bash "$@" 2>&1 >/dev/null) || true
  if printf '%s' "$err" | grep -qF "$pattern"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (stderr 中未找到: \"%s\")${NC}\n" "$name" "$pattern"
    printf "     实际 stderr: %s\n" "$err"
    fail=$((fail+1))
  fi
}

echo "== cron 校验 =="

assert 0 "5 段合法:标准 * * * * *" \
  -- "$BIN" cron "* * * * *"

assert 0 "5 段合法:工作日 9 点" \
  -- "$BIN" cron "0 9 * * 1-5"

assert 0 "5 段合法:每月 1 日午夜" \
  -- "$BIN" cron "0 0 1 * *"

assert 0 "5 段合法:含步进 */5" \
  -- "$BIN" cron "*/5 * * * *"

assert 0 "5 段合法:含逗号 1,15" \
  -- "$BIN" cron "0 12 1,15 * *"

assert 0 "6 段合法:含秒字段" \
  -- "$BIN" cron "30 0 9 * * 1-5"

assert 2 "4 段不足:拦截" \
  -- "$BIN" cron "* * * *"

assert 2 "3 段不足:拦截" \
  -- "$BIN" cron "0 9 *"

assert 2 "7 段过多:拦截" \
  -- "$BIN" cron "0 0 9 * * 1-5 extra"

assert 2 "含感叹号非法字符:拦截" \
  -- "$BIN" cron "0 9 * * 1!"

assert 2 "含 @ 字符:拦截" \
  -- "$BIN" cron "@ 9 * * *"

assert_stderr_contains "4 段错误含中文字段提示" "字段数" \
  "$BIN" cron "* * * *"

assert_stderr_contains "非法字符错误含提示关键词" "非法字符" \
  "$BIN" cron "0 9 * * 1!"

echo ""
echo "== regex 校验 =="

assert 0 "合法 ERE:字母范围" \
  -- "$BIN" regex "^[a-z]+$"

assert 0 "合法 ERE:数字组" \
  -- "$BIN" regex "[0-9]{3}-[0-9]{4}"

assert 0 "合法 ERE:选项 (foo|bar)" \
  -- "$BIN" regex "(foo|bar)"

assert 0 "合法 ERE:可选协议 https?" \
  -- "$BIN" regex "^https?://.+"

assert 0 "合法 ERE:长度量词 {6,20}" \
  -- "$BIN" regex "^.{6,20}$"

assert 2 "未配对左括号 ( :拦截" \
  -- "$BIN" regex "("

assert 2 "量词无操作数 *abc :拦截" \
  -- "$BIN" regex "*abc"

assert 2 "未配对方括号 [ :拦截" \
  -- "$BIN" regex "[abc"

assert_stderr_contains "括号错误 stderr 含「非法」" "非法" \
  "$BIN" regex "("

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
