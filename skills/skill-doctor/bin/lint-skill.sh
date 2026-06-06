#!/usr/bin/env bash
# lint-skill.sh — 校验单个 skill 目录是否符合合集约定
# 用法: lint-skill.sh <skill目录>
# 退出码: 0=通过(或只有 warning) / 2=有 error
set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

if [ $# -ne 1 ]; then
  printf "${RED}用法: lint-skill.sh <skill目录>${NC}\n" >&2
  exit 1
fi

SKILL_DIR="${1%/}"   # 去掉末尾斜杠

if [ ! -d "$SKILL_DIR" ]; then
  printf "${RED}错误: 目录不存在: %s${NC}\n" "$SKILL_DIR" >&2
  exit 1
fi

SKILL_NAME="$(basename "$SKILL_DIR")"
errors=()
warnings=()

# ------------------------------------------------------------------
# 工具函数
# ------------------------------------------------------------------
add_error()   { errors+=("$1"); }
add_warning() { warnings+=("$1"); }

# 从 SKILL.md 中提取 frontmatter 块(两个 --- 之间)
frontmatter_value() {
  local key="$1" file="$2"
  # 取第一个 --- 和第二个 --- 之间的内容,查找 key: value
  awk '/^---/{f=!f; next} f{print}' "$file" | grep "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//"
}

has_frontmatter() {
  # SKILL.md 首行是 ---,且文件中有第二个 ---
  local file="$1"
  local fences
  fences=$(grep -c '^---$' "$file" 2>/dev/null || true)
  [ "$fences" -ge 2 ]
}

# ------------------------------------------------------------------
# 检查 1: 存在 SKILL.md
# ------------------------------------------------------------------
SKILL_MD="$SKILL_DIR/SKILL.md"
if [ ! -f "$SKILL_MD" ]; then
  add_error "缺少 SKILL.md"
else
  # 检查 2: YAML frontmatter 存在且含 name: 与 description:
  if ! has_frontmatter "$SKILL_MD"; then
    add_error "SKILL.md 缺少 YAML frontmatter(须以 --- 开头和结尾)"
  else
    fm_name="$(frontmatter_value name "$SKILL_MD")"
    fm_desc="$(frontmatter_value description "$SKILL_MD")"

    if [ -z "$fm_name" ]; then
      add_error "SKILL.md frontmatter 缺少 name: 字段"
    fi
    if [ -z "$fm_desc" ]; then
      add_error "SKILL.md frontmatter 缺少 description: 字段"
    fi

    # 检查 3: name 值 == 目录名
    if [ -n "$fm_name" ] && [ "$fm_name" != "$SKILL_NAME" ]; then
      add_error "SKILL.md frontmatter name(${fm_name})与目录名(${SKILL_NAME})不一致"
    fi

    # 检查 7(warning): description 建议含触发线索(触发/使用/时用/trigger/when 等)
    if [ -n "$fm_desc" ] && ! printf '%s' "$fm_desc" | grep -qiE '触发|时使用|时用|使用时|当用户|trigger|when |use when'; then
      add_warning "description 未含触发线索,建议注明何时触发(如 当用户说"…"时触发)"
    fi
  fi
fi

# ------------------------------------------------------------------
# 检查 4: 存在 README.md
# ------------------------------------------------------------------
README="$SKILL_DIR/README.md"
if [ ! -f "$README" ]; then
  add_error "缺少 README.md"
else
  # 检查 5: README.md 含徽章(img.shields.io)
  if ! grep -q 'img\.shields\.io' "$README"; then
    add_error "README.md 未包含 img.shields.io 徽章"
  fi
fi

# ------------------------------------------------------------------
# 检查 6: 有 bin/*.sh 时必须有 tests/run.sh
# ------------------------------------------------------------------
BIN_DIR="$SKILL_DIR/bin"
TESTS_RUN="$SKILL_DIR/tests/run.sh"
if [ -d "$BIN_DIR" ]; then
  has_sh=0
  while IFS= read -r -d '' f; do
    has_sh=1; break
  done < <(find "$BIN_DIR" -maxdepth 1 -name '*.sh' -print0 2>/dev/null)

  if [ "$has_sh" = "1" ] && [ ! -f "$TESTS_RUN" ]; then
    add_error "存在 bin/*.sh 却缺少 tests/run.sh"
  fi
fi

# ------------------------------------------------------------------
# 输出结果
# ------------------------------------------------------------------
printf "== skill-doctor: %s ==\n" "$SKILL_NAME"

if [ "${#warnings[@]}" -gt 0 ]; then
  for w in "${warnings[@]}"; do
    printf "${YELLOW}⚠ 警告: %s${NC}\n" "$w"
  done
fi

if [ "${#errors[@]}" -gt 0 ]; then
  for e in "${errors[@]}"; do
    printf "${RED}✗ 错误: %s${NC}\n" "$e"
  done
  printf "${RED}检查未通过(%d 个错误)。请修复后再发布。${NC}\n" "${#errors[@]}"
  exit 2
fi

printf "${GREEN}✅ 通过${NC}\n"
exit 0
