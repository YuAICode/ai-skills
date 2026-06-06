#!/usr/bin/env bash
# fetch-errors.sh — 拉某 Lambda 在时间窗内的 CloudWatch 报错日志(原始文本,供 Claude 聚类)
# 用法:
#   fetch-errors.sh <函数名|--group 日志组> [窗口] [region]
#     窗口:1h(默认)/ 6h / 24h / 7d
#     例:fetch-errors.sh my-func 6h ap-southeast-1
#         fetch-errors.sh --group /aws/lambda/my-func 24h
# 依赖:aws CLI + 凭据。可用 AWS_CLI 覆盖二进制(测试/自定义)。
set -uo pipefail

AWS_CLI="${AWS_CLI:-aws}"
command -v "$AWS_CLI" >/dev/null 2>&1 || { echo "ERROR: 未找到 aws CLI(装 AWS CLI 并配置凭据;或设 AWS_CLI 指向二进制)" >&2; exit 1; }

# 解析参数
group=""; fn=""; window="1h"; region=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --group) group="$2"; shift 2;;
    *) args+=("$1"); shift;;
  esac
done
[ "${#args[@]}" -ge 1 ] && [ -z "$group" ] && fn="${args[0]}"
[ "${#args[@]}" -ge 2 ] && window="${args[1]}"
[ "${#args[@]}" -ge 3 ] && region="${args[2]}"
[ -z "$group" ] && [ -n "$fn" ] && group="/aws/lambda/$fn"
[ -z "$group" ] && { echo "ERROR: 需要函数名或 --group 日志组名" >&2; exit 1; }

# 窗口 → 起始毫秒时间戳(兼容 macOS / Linux date)
num="${window%[hdHD]}"; unit="${window#$num}"
case "$unit" in h|H) secs=$((num*3600));; d|D) secs=$((num*86400));; *) secs=3600;; esac
if date -v-1H +%s >/dev/null 2>&1; then            # macOS (BSD date)
  start_s=$(($(date +%s) - secs))
else                                               # GNU date
  start_s=$(($(date +%s) - secs))
fi
start_ms=$((start_s * 1000))

region_args=(); [ -n "$region" ] && region_args=(--region "$region")

echo "LOG_GROUP: $group"
echo "WINDOW: 最近 $window"
echo "ERRORS:"
# CloudWatch filter pattern:任一关键词命中即返回
# ${arr[@]+...} 守卫:bash 3.2 + set -u 下空数组展开不报 unbound
"$AWS_CLI" logs filter-log-events \
  ${region_args[@]+"${region_args[@]}"} \
  --log-group-name "$group" \
  --start-time "$start_ms" \
  --filter-pattern '?ERROR ?Error ?Exception ?Traceback ?panic ?FATAL ?"Task timed out"' \
  --query 'events[].message' \
  --output text 2>&1
