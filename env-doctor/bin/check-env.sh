#!/usr/bin/env bash
# check-env.sh — 项目跑前 .env 配置体检
# 用法:
#   check-env.sh [项目目录]
#   项目目录缺省 = 当前目录
#
# 退出码:
#   0 — 全部 OK(或仅有警告)
#   2 — 存在缺失 key 或空值 key(需要用户补全)
set -uo pipefail

# ---------- 颜色 ----------
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info(){ printf "${CYAN}[env-doctor]${NC} %s\n" "$1"; }
warn(){ printf "${YELLOW}[警告]${NC} %s\n" "$1"; }
error(){ printf "${RED}[缺失]${NC} %s\n" "$1"; }
ok(){ printf "${GREEN}[✓]${NC} %s\n" "$1"; }

# ---------- 参数 ----------
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR" || { printf "${RED}ERROR: 目录不存在:%s${NC}\n" "$PROJECT_DIR" >&2; exit 1; }
REAL_DIR="$(pwd)"

info "体检目录:$REAL_DIR"
echo ""

# ---------- 查找 .env.example 变体 ----------
EXAMPLE_FILE=""
for candidate in .env.example .env.sample .env.template; do
  if [ -f "$candidate" ]; then
    EXAMPLE_FILE="$candidate"
    break
  fi
done

# ---------- 情形一:没有模板文件 ----------
if [ -z "$EXAMPLE_FILE" ]; then
  info "未找到 .env.example / .env.sample / .env.template,跳过 key 对比。"
  if [ -f .env ]; then
    ok ".env 存在。"
  else
    warn ".env 也不存在,项目可能不需要环境配置,或尚未初始化。"
  fi
  exit 0
fi

info "模板文件:$EXAMPLE_FILE"

# ---------- 情形二:有模板但没有 .env ----------
if [ ! -f .env ]; then
  warn "发现 $EXAMPLE_FILE,但 .env 文件不存在!"
  echo ""
  echo "  建议:"
  echo "    cp $EXAMPLE_FILE .env"
  echo "    # 然后编辑 .env,填入真实值"
  echo ""
  echo "  ⚠️  常见坑:有些项目不会自动加载 .env,"
  echo "      需要在运行前手动导入:"
  echo "        set -a; source .env; set +a"
  exit 0
fi

info ".env 存在,开始对比 key …"
echo ""

# ---------- 解析函数:提取 KEY= 形式的 key 列表 ----------
# 规则:
#   - 忽略注释行(# 开头,含前置空格)
#   - 忽略空行
#   - 只取 KEY= 或 KEY=VALUE 形式;KEY 仅含字母/数字/_
extract_keys() {
  local file="$1"
  grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$file" \
    | grep -v '^[[:space:]]*#' \
    | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*).*/\1/' \
    | sort -u
}

# 提取 .env 中 key 的值(供空值检测用)
get_value() {
  local file="$1" key="$2"
  # 取第一个匹配行,去掉 key= 前缀,去掉行内注释,去掉引号,strip 首尾空白
  grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | head -1 \
    | sed -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//" \
    | sed -E "s/[[:space:]]*#.*$//" \
    | sed -E "s/^['\"](.*)['\"]/\1/" \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//'
}

EXAMPLE_KEYS="$(extract_keys "$EXAMPLE_FILE")"
ENV_KEYS="$(extract_keys .env)"

missing_keys=()
empty_keys=()

while IFS= read -r key; do
  [ -z "$key" ] && continue
  # 检查是否缺失
  if ! printf '%s\n' "$ENV_KEYS" | grep -qx "$key"; then
    missing_keys+=("$key")
  else
    # key 存在,检查值是否为空
    val="$(get_value .env "$key")"
    if [ -z "$val" ]; then
      empty_keys+=("$key")
    fi
  fi
done <<< "$EXAMPLE_KEYS"

# ---------- 汇报结果 ----------
HAS_ISSUE=0

if [ ${#missing_keys[@]} -gt 0 ]; then
  HAS_ISSUE=1
  echo "--- 缺失的 key(在 $EXAMPLE_FILE 中有,但 .env 里没有) ---"
  for k in "${missing_keys[@]}"; do
    error "$k"
  done
  echo ""
fi

if [ ${#empty_keys[@]} -gt 0 ]; then
  HAS_ISSUE=1
  echo "--- 值为空的 key(key 存在但未赋值) ---"
  for k in "${empty_keys[@]}"; do
    warn "$k  (值为空)"
  done
  echo ""
fi

if [ "$HAS_ISSUE" -eq 0 ]; then
  ok ".env 配置完整,所有 $EXAMPLE_FILE 中的 key 均已赋值。"
  echo ""
  echo "  提示:如果程序仍读不到环境变量,可能是 .env 没被自动加载。"
  echo "  手动导入方式:  set -a; source .env; set +a"
  exit 0
else
  echo "  建议:编辑 .env 补全上述 key 后再运行项目。"
  echo "  提示:填完后可再跑一次本脚本确认:  bash check-env.sh"
  exit 2
fi
