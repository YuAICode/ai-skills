#!/usr/bin/env bash
# parse-curl.sh — 把一条 curl 命令拆成结构化字段输出(纯解析,不执行请求)
#
# 用法:
#   parse-curl.sh "<curl 命令>"
#
# 输出(每行一个字段):
#   METHOD=<GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|…>
#   URL=<https://…>
#   HEADERS=<K: V | K: V | …>   (多个头用 " | " 分隔;无则输出 HEADERS=)
#   DATA=<请求体>               (无则输出 DATA=)
#   FLAGS=<-L -k -s …>         (非 URL/头/体的其余 flag;无则输出 FLAGS=)
#
# exit 0 = 成功
# exit 1 = 用法错误
# exit 2 = 输入不是有效 curl 命令(不以 curl 开头,或缺 URL)
#
# 兼容 bash 3.2+;不依赖 python/jq/perl 等外部工具。
# 严格不执行任何网络请求。

set -uo pipefail

usage() {
  printf '用法: %s "<curl 命令>"\n' "$(basename "$0")" >&2
  exit 1
}

[ $# -eq 1 ] || usage

INPUT="$1"

# ── 去掉行尾续行符和多余空白,把多行拼成单行 ──────────────────────────────
# 把 ' \\\n' 或 ' \\\r\n' → 空格
FLAT=$(printf '%s' "$INPUT" | tr '\r' ' ' | sed 's/ *\\$//')
# 把换行符统一成空格
FLAT=$(printf '%s' "$FLAT" | tr '\n' ' ')
# 压缩连续空格
FLAT=$(printf '%s' "$FLAT" | sed 's/  */ /g')
FLAT="${FLAT# }"; FLAT="${FLAT% }"

# ── 检查是否以 curl 开头 ─────────────────────────────────────────────────
case "$FLAT" in
  curl\ *|curl) : ;;
  *)
    printf '错误:输入不是有效的 curl 命令(须以 "curl" 开头)。\n' >&2
    exit 2
    ;;
esac

# 去掉开头的 "curl "
FLAT="${FLAT#curl }"
FLAT="${FLAT#curl}"  # 裸 curl(无参数)

# ── Token 分割器:把命令行拆成 argv 数组 ──────────────────────────────────
# bash 3.2 兼容的简单状态机:处理单引号、双引号和裸 token。
# 不支持 $'...' 转义串或 $(…) 展开,但已足够覆盖常见 curl 写法。

split_args() {
  local input="$1"
  local tok='' state='bare' c=''
  local i=0 len=${#input}
  ARGV=()
  while [ $i -lt $len ]; do
    c="${input:$i:1}"
    case "$state" in
      bare)
        case "$c" in
          ' ')
            if [ -n "$tok" ]; then ARGV+=("$tok"); tok=''; fi
            ;;
          "'") state='sq' ;;
          '"') state='dq' ;;
          '\\')
            i=$((i+1))
            c="${input:$i:1}"
            tok="${tok}${c}"
            ;;
          *) tok="${tok}${c}" ;;
        esac
        ;;
      sq)
        case "$c" in
          "'") state='bare' ;;
          *) tok="${tok}${c}" ;;
        esac
        ;;
      dq)
        case "$c" in
          '"') state='bare' ;;
          '\\')
            i=$((i+1))
            c="${input:$i:1}"
            # 在双引号内,\ 只对特定字符转义
            case "$c" in
              '"'|'\\'|'$'|'`'|'!') tok="${tok}${c}" ;;
              *) tok="${tok}\\${c}" ;;
            esac
            ;;
          *) tok="${tok}${c}" ;;
        esac
        ;;
    esac
    i=$((i+1))
  done
  [ -n "$tok" ] && ARGV+=("$tok")
}

split_args "$FLAT"

# ── 解析 argv ─────────────────────────────────────────────────────────────
METHOD=''
URL=''
HEADERS=''
DATA=''
FLAGS=''

# 辅助:追加到 HEADERS(用 " | " 分隔)
append_header() {
  if [ -z "$HEADERS" ]; then
    HEADERS="$1"
  else
    HEADERS="${HEADERS} | $1"
  fi
}

# 辅助:追加到 FLAGS
append_flag() {
  if [ -z "$FLAGS" ]; then
    FLAGS="$1"
  else
    FLAGS="${FLAGS} $1"
  fi
}

argc=${#ARGV[@]}
i=0
while [ $i -lt $argc ]; do
  arg="${ARGV[$i]}"
  case "$arg" in
    # ── 方法 ──
    -X|--request)
      i=$((i+1))
      [ $i -lt $argc ] && METHOD="${ARGV[$i]}"
      ;;
    # ── 请求头 ──
    -H|--header)
      i=$((i+1))
      [ $i -lt $argc ] && append_header "${ARGV[$i]}"
      ;;
    # ── 请求体(各种 --data 变体) ──
    -d|--data|--data-raw|--data-binary|--data-urlencode|--json)
      i=$((i+1))
      [ $i -lt $argc ] && DATA="${ARGV[$i]}"
      ;;
    # ── 认证(-u 也合并到 HEADERS 语义层,同时记录) ──
    -u|--user)
      i=$((i+1))
      if [ $i -lt $argc ]; then
        append_header "Authorization: Basic(via -u ${ARGV[$i]})"
      fi
      ;;
    # ── 输出到文件 ──
    -o|--output)
      i=$((i+1))
      [ $i -lt $argc ] && append_flag "--output ${ARGV[$i]}"
      ;;
    # ── 超时 ──
    --max-time|--connect-timeout)
      i=$((i+1))
      [ $i -lt $argc ] && append_flag "${arg} ${ARGV[$i]}"
      ;;
    # ── 重试 ──
    --retry|--retry-delay|--retry-max-time)
      i=$((i+1))
      [ $i -lt $argc ] && append_flag "${arg} ${ARGV[$i]}"
      ;;
    # ── 代理 ──
    --proxy|-x)
      i=$((i+1))
      [ $i -lt $argc ] && append_flag "${arg} ${ARGV[$i]}"
      ;;
    # ── Cookie ──
    -b|--cookie)
      i=$((i+1))
      [ $i -lt $argc ] && append_header "Cookie: ${ARGV[$i]}"
      ;;
    -c|--cookie-jar)
      i=$((i+1))
      [ $i -lt $argc ] && append_flag "--cookie-jar ${ARGV[$i]}"
      ;;
    # ── 表单字段(-F 记进 DATA) ──
    -F|--form|--form-string)
      i=$((i+1))
      if [ $i -lt $argc ]; then
        if [ -z "$DATA" ]; then
          DATA="form: ${ARGV[$i]}"
        else
          DATA="${DATA} & form: ${ARGV[$i]}"
        fi
      fi
      ;;
    # ── 已知布尔 flag:归入 FLAGS ──
    -L|--location|-k|--insecure|-s|--silent|-S|--show-error|-v|\
--verbose|-i|--include|-I|--head|-O|--remote-name|\
--compressed|--http1.0|--http1.1|--http2|-4|-6|\
--fail|-f|--no-keepalive|--tcp-nodelay|--no-buffer)
      append_flag "$arg"
      ;;
    # ── 含等号的长选项(--option=value) ──
    --request=*) METHOD="${arg#--request=}" ;;
    --header=*)  append_header "${arg#--header=}" ;;
    --data=*)    DATA="${arg#--data=}" ;;
    --data-raw=*)    DATA="${arg#--data-raw=}" ;;
    --data-binary=*) DATA="${arg#--data-binary=}" ;;
    --data-urlencode=*) DATA="${arg#--data-urlencode=}" ;;
    --json=*)    DATA="${arg#--json=}" ;;
    --user=*)    append_header "Authorization: Basic(via -u ${arg#--user=})" ;;
    --output=*)  append_flag "--output ${arg#--output=}" ;;
    --max-time=*)  append_flag "${arg}" ;;
    --connect-timeout=*) append_flag "${arg}" ;;
    --retry=*)   append_flag "${arg}" ;;
    --proxy=*)   append_flag "${arg}" ;;
    --cookie=*)  append_header "Cookie: ${arg#--cookie=}" ;;
    --cookie-jar=*) append_flag "${arg}" ;;
    # ── URL:http:// https:// ftp:// 或 //... ──
    http://*|https://*|ftp://*|ftps://*|//*|file://*)
      [ -z "$URL" ] && URL="$arg"
      ;;
    # ── 其余:若看起来像 flag(以 - 开头)则加进 FLAGS ──
    -*)
      append_flag "$arg"
      ;;
    # ── 裸字符串:若 URL 未定且看起来像域名/路径,设为 URL ──
    *)
      if [ -z "$URL" ]; then
        URL="$arg"
      fi
      ;;
  esac
  i=$((i+1))
done

# ── 补全默认方法 ──────────────────────────────────────────────────────────
if [ -z "$METHOD" ]; then
  if [ -n "$DATA" ]; then
    METHOD='POST'   # curl 默认:有 -d 则 POST
  elif printf '%s' "$FLAT" | grep -qE ' -(I|-head)\b'; then
    METHOD='HEAD'
  else
    METHOD='GET'
  fi
fi

# ── 校验:必须有 URL ──────────────────────────────────────────────────────
if [ -z "$URL" ]; then
  printf '错误:未能从命令中识别出 URL。\n' >&2
  exit 2
fi

# ── 输出 ─────────────────────────────────────────────────────────────────
printf 'METHOD=%s\n' "$METHOD"
printf 'URL=%s\n'    "$URL"
printf 'HEADERS=%s\n' "$HEADERS"
printf 'DATA=%s\n'   "$DATA"
printf 'FLAGS=%s\n'  "$FLAGS"
exit 0
