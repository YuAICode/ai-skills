#!/usr/bin/env bash
# validate.sh — 轻量校验 cron 表达式或正则表达式(ERE)
# 用法:
#   validate.sh cron "<表达式>"   # exit 0=合法  exit 2=非法  exit 1=用法错误
#   validate.sh regex "<模式>"
set -uo pipefail

usage() {
  printf '用法:\n'
  printf '  %s cron "<表达式>"\n' "$(basename "$0")"
  printf '  %s regex "<模式>"\n' "$(basename "$0")"
  exit 1
}

[ $# -eq 2 ] || usage

MODE="$1"
INPUT="$2"

# ──────────────────────────────────────────────
# cron 校验
# ──────────────────────────────────────────────
validate_cron() {
  local expr="$1"

  # 去除首尾空白
  expr="${expr#"${expr%%[![:space:]]*}"}"
  expr="${expr%"${expr##*[![:space:]]}"}"

  # 计算字段数(按空白分割)
  local fields
  read -ra fields <<< "$expr"
  local count="${#fields[@]}"

  if [ "$count" -lt 5 ] || [ "$count" -gt 6 ]; then
    printf '错误:cron 表达式字段数为 %d,须为 5(分 时 日 月 周)或 6(秒 分 时 日 月 周)段。\n' "$count" >&2
    exit 2
  fi

  # 粗校验每段:只允许数字、* , - / ? L W # 及大小写字母(月份/星期缩写)
  local i
  for i in "${!fields[@]}"; do
    local field="${fields[$i]}"
    if ! printf '%s' "$field" | grep -qE '^[0-9A-Za-z*,/#?LW-]+$'; then
      printf '错误:第 %d 段 "%s" 含有非法字符。合法字符:数字、*、,、-、/、?、L、W、#、字母(月/周缩写)。\n' "$((i+1))" "$field" >&2
      exit 2
    fi
  done

  printf 'cron 表达式格式合法(%d 段)。\n' "$count"
  exit 0
}

# ──────────────────────────────────────────────
# regex 校验(POSIX ERE,用 grep -E 干跑)
# ──────────────────────────────────────────────
validate_regex() {
  local pattern="$1"
  local err_msg
  # 把 stderr 捕获到变量;stdout 扔掉;exit 1 = 无匹配(合法),exit 2+ = 语法错误
  err_msg=$(printf '' | grep -E -- "$pattern" 2>&1 1>/dev/null) || true
  local grep_exit=$?

  # grep exit codes:
  #   0 = 有匹配(对空输入不可能,除非模式可匹配空串)
  #   1 = 无匹配但语法合法
  #   2 = 语法错误(ugrep/grep 均如此)
  if [ -n "$err_msg" ]; then
    printf '错误:正则表达式语法非法(POSIX ERE)。\n详情:%s\n提示:如使用 PCRE 特性(如 \\d、(?:…)),请改用 PCRE 引擎或调整写法。\n' "$err_msg" >&2
    exit 2
  fi

  # stderr 为空 → 合法(exit 0 或 1 均视为"语法 OK")
  printf '正则表达式语法合法(POSIX ERE)。\n'
  exit 0
}

case "$MODE" in
  cron)  validate_cron  "$INPUT" ;;
  regex) validate_regex "$INPUT" ;;
  *) printf '错误:未知子命令 "%s"。须为 cron 或 regex。\n' "$MODE" >&2; usage ;;
esac
