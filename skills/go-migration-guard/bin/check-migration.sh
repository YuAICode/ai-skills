#!/usr/bin/env bash
# check-migration.sh — 启发式检查 GORM 模型字段改动是否有迁移覆盖
#
# 用法:
#   check-migration.sh [base]          扫 git diff <base>..HEAD 里的 .go 文件
#   check-migration.sh --diff <文件>    从指定 diff 文件读取(测试/离线用)
#
# 退出码:
#   0  没有检测到 gorm 字段变更(放行)
#   2  发现带 gorm tag 的字段新增/删除,需人工确认迁移覆盖
#
# 注意:这是启发式检查,不能保证"没问题"。Claude 应结合实际 migration 文件判断。
set -uo pipefail

YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

# ---- 获取 diff 文本 ----
# 支持三种模式:
#   1. --diff <文件>   直接从文件读(测试用)
#   2. <base>          git diff <base>..HEAD
#   3. 无参数          自动探测 main/master 作为 base
collect_diff() {
  if [ "${1:-}" = "--diff" ] && [ -n "${2:-}" ]; then
    cat "$2"
    return
  fi

  local base="${1:-}"
  if [ -z "$base" ]; then
    # 自动探测 base branch
    if git rev-parse --verify main >/dev/null 2>&1; then
      base="main"
    elif git rev-parse --verify master >/dev/null 2>&1; then
      base="master"
    else
      printf "${YELLOW}[go-migration-guard] 警告:找不到 main/master 分支,请手动指定 base。${NC}\n" >&2
      printf "${YELLOW}  用法:check-migration.sh <base-branch-or-commit>${NC}\n" >&2
      exit 0
    fi
  fi

  git diff "${base}..HEAD" -- '*.go' 2>/dev/null
}

# ---- 解析参数 ----
DIFF_FILE=""
BASE=""
if [ "${1:-}" = "--diff" ]; then
  DIFF_FILE="${2:-}"
  [ -n "$DIFF_FILE" ] || { echo "错误:--diff 需要文件路径" >&2; exit 1; }
  [ -f "$DIFF_FILE" ] || { echo "错误:文件不存在:$DIFF_FILE" >&2; exit 1; }
else
  BASE="${1:-}"
fi

# ---- 取 diff ----
if [ -n "$DIFF_FILE" ]; then
  raw_diff="$(cat "$DIFF_FILE")"
else
  raw_diff="$(collect_diff "$BASE")"
fi

[ -z "$raw_diff" ] && exit 0

# ---- 提取带 gorm tag 的新增/删除字段行 ----
# 匹配模式:diff 中以 + 或 - 开头(排除 +++ / ---),且行内含 gorm:"
# 捕获来源文件名以便定位
gorm_changes=""
current_file=""

while IFS= read -r line; do
  # 更新当前文件名(diff header: +++ b/path/to/file.go)
  if printf '%s' "$line" | grep -qE '^\+\+\+ b/'; then
    current_file="${line#+++ b/}"
    continue
  fi
  # 跳过 diff 元数据行
  printf '%s' "$line" | grep -qE '^(\+\+\+|---|\\ No newline|diff |index |@@)' && continue

  # 匹配新增行(+)或删除行(-)且含 gorm:"
  if printf '%s' "$line" | grep -qE '^[+-]' && printf '%s' "$line" | grep -qE 'gorm:"'; then
    prefix="${line:0:1}"
    content="${line:1}"
    if [ -n "$current_file" ]; then
      gorm_changes="${gorm_changes}${prefix} ${current_file}: ${content}"$'\n'
    else
      gorm_changes="${gorm_changes}${prefix} ${content}"$'\n'
    fi
  fi
done <<< "$raw_diff"

# 去掉末尾空行
gorm_changes="${gorm_changes%$'\n'}"

# ---- 如果没有 gorm 字段变更 → 放行 ----
if [ -z "$gorm_changes" ]; then
  exit 0
fi

# ---- 检测迁移线索 ----
# 线索1: migration 目录有改动
migration_dir_changed=""
if printf '%s' "$raw_diff" | grep -qE '^diff --git.*/(migration|migrations|db/migrate|migrate)/'; then
  migration_dir_changed="yes"
fi

# 线索2: AutoMigrate 字样出现在 diff 的新增行
automigrate_added=""
if printf '%s' "$raw_diff" | grep -qE '^\+.*AutoMigrate'; then
  automigrate_added="yes"
fi

# 线索3: 手动 migration SQL/AddColumn 等字样
manual_migration=""
if printf '%s' "$raw_diff" | grep -qEi '^\+.*(AddColumn|DropColumn|AlterColumn|CreateTable|DropTable|Migrator\(\)|db\.Exec.*ALTER)'; then
  manual_migration="yes"
fi

has_migration_hint=""
[ -n "$migration_dir_changed" ] || [ -n "$automigrate_added" ] || [ -n "$manual_migration" ] && has_migration_hint="yes"

# ---- 输出报告 ----
printf "${BOLD}${CYAN}[go-migration-guard] 启发式迁移覆盖检查${NC}\n" >&2
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" >&2
printf "\n" >&2
printf "以下带 gorm tag 的 struct 字段在本次 diff 中有新增(+)或删除(-),\n" >&2
printf "请确认这些字段变更有对应的 migration 覆盖(或 AutoMigrate 已含):\n\n" >&2

while IFS= read -r line; do
  [ -z "$line" ] && continue
  prefix="${line:0:1}"
  rest="${line:2}"
  if [ "$prefix" = "+" ]; then
    printf "  ${GREEN:-}+ %s${NC}\n" "$rest" >&2
  else
    printf "  ${RED}– %s${NC}\n" "$rest" >&2
  fi
done <<< "$gorm_changes"

printf "\n" >&2

# 迁移线索评估
if [ -n "$has_migration_hint" ]; then
  printf "${CYAN}迁移线索评估:${NC}\n" >&2
  [ -n "$migration_dir_changed" ] && printf "  ✓ diff 中包含 migration 目录改动\n" >&2
  [ -n "$automigrate_added" ] && printf "  ✓ diff 中有 AutoMigrate 调用新增\n" >&2
  [ -n "$manual_migration" ] && printf "  ✓ diff 中有手动 DDL/Migrator 操作\n" >&2
  printf "\n" >&2
  printf "${YELLOW}⚠  找到迁移线索,但请人工确认覆盖范围正确(字段名/类型/表名是否匹配)。${NC}\n" >&2
else
  printf "${RED}${BOLD}⛔  未发现任何迁移线索(migration 目录未动、无 AutoMigrate、无手动 DDL)。${NC}\n" >&2
  printf "\n" >&2
  printf "  如果项目依赖手写 migration 文件:请补写对应迁移,否则生产库 schema 将与模型不一致。\n" >&2
  printf "  如果项目用 AutoMigrate:确认它在服务启动时会被执行,且已含上述字段。\n" >&2
  printf "  历史教训:迁移链断 → Lambda 跑新代码 + 旧 schema → 数据静默丢失。\n" >&2
fi

printf "\n" >&2
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" >&2
printf "${YELLOW}注:本检查为启发式,不能保证迁移完整。Claude 应结合实际 migration 文件内容判断。${NC}\n" >&2

exit 2
