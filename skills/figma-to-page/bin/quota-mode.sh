#!/usr/bin/env bash
# quota-mode.sh — 决定这台机器上 figma-to-page 用哪种取数策略。
#
# 为什么需要:Figma MCP 读取类工具的配额差了 100 倍(Starter View seat 20 次/月,
# Enterprise Dev seat 600 次/天)。把「省调用」写死成默认,对配额充裕的人就是白白
# 牺牲还原精度 —— 省调用模式跳过 get_metadata、不分区块拉 context,大 frame 会糊。
# 所以策略要可配置,而不是硬编码。
#
# 用法:
#   quota-mode.sh                        打印当前模式与来源(给阶段 0 用)
#   quota-mode.sh set <值>               写入用户配置(unlimited | thrifty | auto)
#   quota-mode.sh resolve <seat> <tier>  auto 模式下按 whoami 结果判定实际模式
#   quota-mode.sh where                  打印配置文件路径
#
# 配置值:
#   unlimited  实测不受配额约束 → 走完整模式,且不必向用户汇报预计调用次数
#   thrifty    配额紧张 → 走省调用模式(每帧 2-3 次调用)
#   auto       (默认)由阶段 0 的 whoami 结果决定,见 resolve
#
# 优先级:环境变量 FIGMA_QUOTA_MODE > 用户配置文件 > auto
# 配置文件:${XDG_CONFIG_HOME:-~/.config}/figma-to-page/quota.conf
#
# 输出的 MODE 只有两种终态:full(完整模式) | thrifty(省调用模式)。
# REPORT_QUOTA=no 时不要再向用户播报「本次预计 N 次调用」。
#
# 退出码: 0=成功 / 2=用法错误
set -uo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/figma-to-page"
CONFIG_FILE="$CONFIG_DIR/quota.conf"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

usage() {
  sed -n '3,29p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

check_value() {
  case "$1" in
    unlimited|thrifty|auto) return 0 ;;
    *) printf "错误: 模式必须是 unlimited / thrifty / auto,收到: %s\n" "$1" >&2; exit 2 ;;
  esac
}

# 读配置值。只取 quota.conf 里第一行非空非注释内容,不 source 文件(避免执行任意代码)。
read_configured() {
  if [ -n "${FIGMA_QUOTA_MODE:-}" ]; then
    printf '%s\t%s' "$FIGMA_QUOTA_MODE" "环境变量 FIGMA_QUOTA_MODE"
    return 0
  fi
  if [ -f "$CONFIG_FILE" ]; then
    local v
    v="$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$CONFIG_FILE" | grep -v '^$' | head -1)"
    if [ -n "$v" ]; then
      printf '%s\t%s' "$v" "$CONFIG_FILE"
      return 0
    fi
  fi
  printf '%s\t%s' "auto" "默认值(无配置)"
}

# auto 判定:按官方 rate-limits 表把 seat + tier 映射成两档策略。
# View/Collab 一律 thrifty(20 次/月 或 6 次/月,都撑不住完整模式)。
# Dev/Full 只有在付费 plan 上才够用(200-600 次/天);starter 的 Dev seat 仍是 20 次/月。
resolve_auto() {
  local seat tier
  seat="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  tier="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
  case "$seat" in
    dev|full)
      case "$tier" in
        professional|organization|enterprise) printf 'full' ;;
        *) printf 'thrifty' ;;   # starter 的 Dev seat 也只有 20 次/月
      esac
      ;;
    *) printf 'thrifty' ;;       # View / Collab / 未知 → 保守
  esac
}

CMD="${1:-show}"

case "$CMD" in
  show)
    IFS=$'\t' read -r VALUE SOURCE <<<"$(read_configured)"
    check_value "$VALUE"
    case "$VALUE" in
      unlimited)
        printf 'MODE=full\n'
        printf 'REPORT_QUOTA=no\n'
        printf 'SOURCE=%s\n' "$SOURCE"
        printf "${GREEN}[quota-mode] unlimited —— 走完整模式,无需汇报预计调用次数${NC}\n" >&2
        ;;
      thrifty)
        printf 'MODE=thrifty\n'
        printf 'REPORT_QUOTA=yes\n'
        printf 'SOURCE=%s\n' "$SOURCE"
        printf "${YELLOW}[quota-mode] thrifty —— 走省调用模式,每帧 2-3 次调用${NC}\n" >&2
        ;;
      auto)
        printf 'MODE=auto\n'
        printf 'REPORT_QUOTA=yes\n'
        printf 'SOURCE=%s\n' "$SOURCE"
        printf "${YELLOW}[quota-mode] auto —— 请调 whoami(不计配额)拿 seat 与 tier,再跑:${NC}\n" >&2
        printf "${YELLOW}             bash %s resolve <seat> <tier>${NC}\n" "$0" >&2
        ;;
    esac
    ;;

  resolve)
    [ $# -ne 3 ] && usage
    M="$(resolve_auto "$2" "$3")"
    printf 'MODE=%s\n' "$M"
    printf 'REPORT_QUOTA=yes\n'
    printf 'SOURCE=auto(seat=%s, tier=%s)\n' "$2" "$3"
    ;;

  set)
    [ $# -ne 2 ] && usage
    check_value "$2"
    mkdir -p "$CONFIG_DIR" || { printf "错误: 无法创建配置目录 %s\n" "$CONFIG_DIR" >&2; exit 2; }
    printf '# figma-to-page 取数策略: unlimited | thrifty | auto\n%s\n' "$2" > "$CONFIG_FILE" || exit 2
    printf "${GREEN}[quota-mode] 已写入 %s: %s${NC}\n" "$CONFIG_FILE" "$2"
    ;;

  where)
    printf '%s\n' "$CONFIG_FILE"
    ;;

  -h|--help|help) usage ;;
  *) printf "未知命令: %s\n\n" "$CMD" >&2; usage ;;
esac
