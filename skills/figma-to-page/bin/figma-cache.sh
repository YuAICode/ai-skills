#!/usr/bin/env bash
# figma-cache.sh — 把 Figma MCP 的「按文件而非按页面」结果缓存到磁盘,跨 frame / 跨会话复用。
#
# 为什么需要:Figma MCP 的读取类工具有配额(Starter + View/Collab seat 仅 20 次/月)。
# design variables 和 Code Connect 映射是**整个设计文件级别**的数据,不随页面变化,
# 每个 frame 重新拉一次纯属浪费配额。缓存后同一个文件只付一次。
#
# 用法:
#   figma-cache.sh path  <fileKey> <kind>              打印缓存文件路径(不管是否存在)
#   figma-cache.sh get   <fileKey> <kind> [最大天数]    命中则输出内容并 exit 0;未命中/过期 exit 1
#   figma-cache.sh put   <fileKey> <kind> <源文件>      写入缓存(源文件为 - 时读 stdin)
#   figma-cache.sh list                                列出所有缓存条目及年龄
#   figma-cache.sh clear [fileKey]                     清除全部或指定文件的缓存
#
# kind 取值:variables | codeconnect
# 缓存目录:${XDG_CACHE_HOME:-~/.cache}/figma-to-page/
# 默认过期天数:30(design token 会变,过期就重新拉一次)
#
# 退出码: 0=成功/命中 / 1=未命中或过期 / 2=用法错误
set -uo pipefail

CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/figma-to-page"
DEFAULT_MAX_AGE_DAYS=30

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

usage() {
  sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

# 校验 kind,避免拼错导致缓存永不命中(静默失效比报错更难查)
check_kind() {
  case "$1" in
    variables|codeconnect) return 0 ;;
    *) printf "错误: kind 必须是 variables 或 codeconnect,收到: %s\n" "$1" >&2; exit 2 ;;
  esac
}

# fileKey 只允许字母数字,防止路径穿越
check_filekey() {
  case "$1" in
    *[!0-9a-zA-Z]*|"") printf "错误: fileKey 含非法字符或为空: %s\n" "$1" >&2; exit 2 ;;
  esac
}

cache_path() {
  printf '%s/%s.%s.json' "$CACHE_ROOT" "$1" "$2"
}

# 文件年龄(天),取整。用 find 的 -mtime 逐级试探,避免依赖 GNU stat。
file_age_days() {
  local f="$1" d=0
  while [ "$d" -le 3650 ]; do
    if [ -n "$(find "$f" -maxdepth 0 -mtime -$((d + 1)) 2>/dev/null)" ]; then
      printf '%s' "$d"; return 0
    fi
    d=$((d + 1))
  done
  printf '9999'
}

CMD="${1:-}"
[ -z "$CMD" ] && usage

case "$CMD" in
  path)
    [ $# -ne 3 ] && usage
    check_filekey "$2"; check_kind "$3"
    cache_path "$2" "$3"
    printf '\n'
    ;;

  get)
    [ $# -lt 3 ] && usage
    check_filekey "$2"; check_kind "$3"
    MAX_AGE="${4:-$DEFAULT_MAX_AGE_DAYS}"
    F="$(cache_path "$2" "$3")"
    if [ ! -s "$F" ]; then
      printf "${YELLOW}[figma-cache] 未命中: %s / %s${NC}\n" "$2" "$3" >&2
      exit 1
    fi
    AGE="$(file_age_days "$F")"
    if [ "$AGE" -gt "$MAX_AGE" ]; then
      printf "${YELLOW}[figma-cache] 已过期(%s 天 > %s 天): %s / %s —— 建议重新拉取${NC}\n" \
        "$AGE" "$MAX_AGE" "$2" "$3" >&2
      exit 1
    fi
    printf "${GREEN}[figma-cache] 命中(%s 天前): %s / %s —— 省下一次 MCP 调用${NC}\n" \
      "$AGE" "$2" "$3" >&2
    cat "$F"
    ;;

  put)
    [ $# -ne 4 ] && usage
    check_filekey "$2"; check_kind "$3"
    SRC="$4"
    F="$(cache_path "$2" "$3")"
    mkdir -p "$CACHE_ROOT" || { printf "错误: 无法创建缓存目录 %s\n" "$CACHE_ROOT" >&2; exit 2; }
    if [ "$SRC" = "-" ]; then
      cat > "$F" || exit 2
    else
      [ -f "$SRC" ] || { printf "错误: 源文件不存在: %s\n" "$SRC" >&2; exit 2; }
      cp "$SRC" "$F" || exit 2
    fi
    if [ ! -s "$F" ]; then
      # 空内容不留缓存,否则后续会命中一个空结果
      rm -f "$F"
      printf "错误: 内容为空,未写入缓存\n" >&2
      exit 2
    fi
    printf "${GREEN}[figma-cache] 已写入: %s${NC}\n" "$F"
    ;;

  list)
    if [ ! -d "$CACHE_ROOT" ]; then
      printf "缓存目录不存在: %s(还没有任何缓存)\n" "$CACHE_ROOT"
      exit 0
    fi
    found=0
    printf "缓存目录: %s\n" "$CACHE_ROOT"
    for f in "$CACHE_ROOT"/*.json; do
      [ -f "$f" ] || continue
      found=1
      base="$(basename "$f")"
      printf "  %-52s %s 天前\n" "$base" "$(file_age_days "$f")"
    done
    [ "$found" = 0 ] && printf "  (空)\n"
    ;;

  clear)
    if [ ! -d "$CACHE_ROOT" ]; then
      printf "缓存目录不存在,无需清理\n"; exit 0
    fi
    if [ $# -ge 2 ]; then
      check_filekey "$2"
      n=0
      for f in "$CACHE_ROOT/$2".*.json; do
        [ -f "$f" ] && rm -f "$f" && n=$((n + 1))
      done
      printf "已清除 %s 的缓存(%d 项)\n" "$2" "$n"
    else
      n=0
      for f in "$CACHE_ROOT"/*.json; do
        [ -f "$f" ] && rm -f "$f" && n=$((n + 1))
      done
      printf "已清除全部缓存(%d 项)\n" "$n"
    fi
    ;;

  -h|--help|help) usage ;;
  *) printf "未知命令: %s\n\n" "$CMD" >&2; usage ;;
esac
