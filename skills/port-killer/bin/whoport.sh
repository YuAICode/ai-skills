#!/usr/bin/env bash
# whoport.sh — 找出占用某 TCP 端口(LISTEN)的进程,给出 kill 命令
# 用法:
#   whoport.sh <端口> [--kill [--yes]]
#     默认:只查,打印进程信息 + 建议的 kill 命令,不真杀 (exit 0=找到 / exit 1=空闲或错误)
#     --kill:打印进程后执行 kill(SIGTERM);须加 --yes 跳过二次确认提示
# 环境变量:
#   LSOF — 覆盖 lsof 二进制路径(默认 lsof)
set -uo pipefail

LSOF_CMD="${LSOF:-lsof}"

# ---------- 颜色 ----------
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

err()  { printf "${RED}错误:${NC}%s\n" "$*" >&2; }
warn() { printf "${YELLOW}警告:${NC}%s\n" "$*" >&2; }
info() { printf "${CYAN}%s${NC}\n" "$*"; }

# ---------- 参数解析 ----------
PORT=""
DO_KILL=0
YES=0

for arg in "$@"; do
  case "$arg" in
    --kill) DO_KILL=1;;
    --yes)  YES=1;;
    -*)     err "未知参数:$arg"; echo "用法:whoport.sh <端口> [--kill [--yes]]" >&2; exit 1;;
    *)
      if [ -z "$PORT" ]; then
        PORT="$arg"
      else
        err "多余参数:$arg"; exit 1
      fi
      ;;
  esac
done

if [ -z "$PORT" ]; then
  err "缺少端口号"
  echo "用法:whoport.sh <端口> [--kill [--yes]]" >&2
  exit 1
fi

# ---------- 端口号校验 ----------
# 必须全为数字
case "$PORT" in
  *[!0-9]*)
    err "端口号必须是整数,收到:\"$PORT\""
    exit 1
    ;;
esac

if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  err "端口号须在 1-65535 范围内,收到:$PORT"
  exit 1
fi

# ---------- 检查 lsof ----------
if ! command -v "$LSOF_CMD" >/dev/null 2>&1; then
  err "未找到 lsof(命令:\"$LSOF_CMD\")"
  echo "" >&2
  echo "替代方案(需自行解析输出):" >&2
  echo "  Linux: ss -ltnp | grep ':${PORT}'" >&2
  echo "  Linux: netstat -tlnp | grep ':${PORT}'" >&2
  echo "  macOS: netstat -anp tcp | grep LISTEN | grep ':${PORT}'" >&2
  echo "" >&2
  echo "安装 lsof:" >&2
  echo "  Debian/Ubuntu: sudo apt install lsof" >&2
  echo "  RHEL/CentOS:   sudo yum install lsof" >&2
  echo "  macOS:         已内置,若缺失: brew install lsof" >&2
  exit 1
fi

# ---------- 查询 ----------
# lsof 输出格式:COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
# 取 LISTEN 状态的 TCP 行
raw_output=""
raw_output="$("$LSOF_CMD" -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"

if [ -z "$raw_output" ]; then
  printf "${YELLOW}端口 %s 没人占用(无 LISTEN 状态进程)${NC}\n" "$PORT"
  exit 1
fi

# ---------- 解析 PID 列表 ----------
# 跳过标题行(第一行 COMMAND),提取 PID(第2列)
pids=""
while IFS= read -r line; do
  # 跳过标题行
  case "$line" in COMMAND*) continue;; esac
  # 取第二个字段作 PID
  pid="$(printf '%s' "$line" | awk '{print $2}')"
  case "$pid" in
    ''|*[!0-9]*) continue;;
  esac
  # 去重
  case " $pids " in
    *" $pid "*) ;;
    *) pids="${pids:+$pids }$pid";;
  esac
done <<EOF
$raw_output
EOF

if [ -z "$pids" ]; then
  warn "lsof 有输出但未能解析出 PID,原始输出如下:"
  printf '%s\n' "$raw_output" >&2
  exit 1
fi

# ---------- 打印进程信息 ----------
printf "\n端口 ${CYAN}%s${NC} 被以下进程占用:\n\n" "$PORT"
printf "  %-8s %-20s %s\n" "PID" "命令" "用户"
printf "  %-8s %-20s %s\n" "--------" "--------------------" "--------"

# 遍历原始输出,打印每个唯一 PID 对应的行
seen_pids=""
while IFS= read -r line; do
  case "$line" in COMMAND*) continue;; esac
  pid="$(printf '%s' "$line" | awk '{print $2}')"
  case "$pid" in ''|*[!0-9]*) continue;; esac
  case " $seen_pids " in
    *" $pid "*) continue;;
  esac
  seen_pids="${seen_pids:+$seen_pids }$pid"
  cmd="$(printf '%s' "$line" | awk '{print $1}')"
  user="$(printf '%s' "$line" | awk '{print $3}')"
  printf "  %-8s %-20s %s\n" "$pid" "$cmd" "$user"
done <<EOF
$raw_output
EOF

echo ""

if [ "$DO_KILL" -eq 0 ]; then
  # ---------- 只查模式:打印建议命令 ----------
  info "建议:kill $pids"
  info "顽固进程:kill -9 $pids"
  printf "${YELLOW}(本次仅查询,未执行 kill)${NC}\n\n"
  exit 0
fi

# ---------- --kill 模式 ----------
if [ "$YES" -eq 0 ]; then
  printf "${YELLOW}即将执行:kill %s${NC}\n" "$pids"
  printf "继续?请重新加 --yes 参数确认(此操作会终止以上进程):\n"
  printf "  whoport.sh %s --kill --yes\n\n" "$PORT"
  exit 1
fi

# 有 --yes:执行 kill
printf "${YELLOW}将要杀死以下进程(SIGTERM):${NC}\n"
printf "  kill %s\n\n" "$pids"

kill_failed=0
for pid in $pids; do
  if kill "$pid" 2>/dev/null; then
    printf "${GREEN}已发送 SIGTERM → PID %s${NC}\n" "$pid"
  else
    printf "${RED}kill %s 失败(可能已退出,或权限不足)${NC}\n" "$pid" >&2
    kill_failed=$((kill_failed + 1))
  fi
done

echo ""
if [ "$kill_failed" -gt 0 ]; then
  warn "$kill_failed 个进程 kill 失败。若需要强制杀:kill -9 $pids"
  exit 1
fi

printf "${GREEN}完成。若进程仍在,可用:kill -9 %s${NC}\n" "$pids"
exit 0
