#!/usr/bin/env bash
# check.sh — 校验 JSON / YAML / TOML 文件语法,报中文错误定位。
# 用法:
#   check.sh <文件路径> [--format]   按扩展名识别类型
#   check.sh -        [--format]   从 stdin 读(自动探测类型)
# 退出码:
#   0 — 合法(或依赖缺失跳过)
#   2 — 语法错误
# 环境变量:
#   PYTHON_BIN — 覆盖 python 解释器(默认 python3)
set -uo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
FORMAT=0
FILE=""

# ---------- 解析参数 ----------
for arg in "$@"; do
  case "$arg" in
    --format) FORMAT=1 ;;
    *) FILE="$arg" ;;
  esac
done

if [ -z "$FILE" ]; then
  printf '用法: check.sh <文件路径|-> [--format]\n' >&2
  exit 1
fi

# ---------- 读取内容 ----------
TMP_FILE=""
if [ "$FILE" = "-" ]; then
  TMP_FILE="$(mktemp)"
  trap 'rm -f "$TMP_FILE"' EXIT
  cat > "$TMP_FILE"
  INPUT_PATH="$TMP_FILE"
  # 探测类型:按内容首字符猜
  first_char="$(head -c1 "$TMP_FILE" 2>/dev/null || true)"
  # 去掉 UTF-8 BOM(少见但存在)
  content_start="$(head -c4 "$TMP_FILE" | tr -d '\r\n\t ' | cut -c1)"
  if [ "$content_start" = '{' ] || [ "$content_start" = '[' ]; then
    TYPE="json"
  else
    # 读第一行尝试判断 TOML(含 = 且不含 : 的非注释行)
    first_line="$(grep -v '^\s*#' "$TMP_FILE" | head -1 || true)"
    if printf '%s' "$first_line" | grep -q '=' && ! printf '%s' "$first_line" | grep -q ':'; then
      TYPE="toml"
    else
      TYPE="yaml"
    fi
  fi
else
  INPUT_PATH="$FILE"
  if [ ! -f "$FILE" ]; then
    printf '错误:文件不存在:%s\n' "$FILE" >&2
    exit 1
  fi
  # 按扩展名判类型
  case "${FILE##*.}" in
    json) TYPE="json" ;;
    yaml|yml) TYPE="yaml" ;;
    toml) TYPE="toml" ;;
    *)
      # 无法识别扩展名时,按内容探测(同 stdin 逻辑)
      content_start="$(head -c4 "$INPUT_PATH" | tr -d '\r\n\t ' | cut -c1)"
      if [ "$content_start" = '{' ] || [ "$content_start" = '[' ]; then
        TYPE="json"
      else
        first_line="$(grep -v '^\s*#' "$INPUT_PATH" | head -1 || true)"
        if printf '%s' "$first_line" | grep -q '=' && ! printf '%s' "$first_line" | grep -q ':'; then
          TYPE="toml"
        else
          TYPE="yaml"
        fi
      fi
      ;;
  esac
fi

# ---------- 校验函数 ----------

check_json() {
  local path="$1"
  local fmt="$2"
  local py_script
  if [ "$fmt" = "1" ]; then
    py_script='
import sys, json
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    print(json.dumps(data, ensure_ascii=False, indent=2))
except json.JSONDecodeError as e:
    print(f"JSON 语法错误:第 {e.lineno} 行,第 {e.colno} 列", file=sys.stderr)
    print(f"  原始报错:{e.msg}", file=sys.stderr)
    sys.exit(2)
'
  else
    py_script='
import sys, json
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        json.load(f)
    print("JSON 语法合法 OK")
except json.JSONDecodeError as e:
    print(f"JSON 语法错误:第 {e.lineno} 行,第 {e.colno} 列", file=sys.stderr)
    print(f"  原始报错:{e.msg}", file=sys.stderr)
    sys.exit(2)
'
  fi
  "$PYTHON_BIN" - "$path" <<< "$py_script"
}

check_yaml() {
  local path="$1"
  local fmt="$2"
  # 先确认 pyyaml 可用
  if ! "$PYTHON_BIN" -c 'import yaml' 2>/dev/null; then
    printf '提示:YAML 校验需要 pyyaml,请先安装:\n' >&2
    printf '  pip install pyyaml\n' >&2
    printf '已跳过 YAML 校验。\n'
    exit 0
  fi
  local py_script
  if [ "$fmt" = "1" ]; then
    py_script='
import sys, yaml
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = yaml.safe_load(f)
    print(yaml.dump(data, allow_unicode=True, default_flow_style=False), end="")
except yaml.YAMLError as e:
    mark = getattr(e, "problem_mark", None)
    if mark:
        print(f"YAML 语法错误:第 {mark.line + 1} 行,第 {mark.column + 1} 列", file=sys.stderr)
    else:
        print("YAML 语法错误", file=sys.stderr)
    print(f"  原始报错:{e}", file=sys.stderr)
    sys.exit(2)
'
  else
    py_script='
import sys, yaml
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        yaml.safe_load(f)
    print("YAML 语法合法 OK")
except yaml.YAMLError as e:
    mark = getattr(e, "problem_mark", None)
    if mark:
        print(f"YAML 语法错误:第 {mark.line + 1} 行,第 {mark.column + 1} 列", file=sys.stderr)
    else:
        print("YAML 语法错误", file=sys.stderr)
    print(f"  原始报错:{e}", file=sys.stderr)
    sys.exit(2)
'
  fi
  "$PYTHON_BIN" - "$path" <<< "$py_script"
}

check_toml() {
  local path="$1"
  local fmt="$2"
  # 先确认 tomllib 可用(py3.11+)
  if ! "$PYTHON_BIN" -c 'import tomllib' 2>/dev/null; then
    printf '提示:TOML 校验需要 Python 3.11+(内置 tomllib),当前版本不满足:\n' >&2
    "$PYTHON_BIN" --version >&2 || true
    printf '  升级 Python 到 3.11+ 或使用 PYTHON_BIN 指定路径。\n' >&2
    printf '已跳过 TOML 校验。\n'
    exit 0
  fi
  local py_script
  if [ "$fmt" = "1" ]; then
    py_script='
import sys, tomllib, json
try:
    with open(sys.argv[1], "rb") as f:
        data = tomllib.load(f)
    # 美化:用 JSON 格式输出(TOML 没有标准 dump 库)
    print(json.dumps(data, ensure_ascii=False, indent=2, default=str))
except tomllib.TOMLDecodeError as e:
    print(f"TOML 语法错误:{e}", file=sys.stderr)
    sys.exit(2)
'
  else
    py_script='
import sys, tomllib
try:
    with open(sys.argv[1], "rb") as f:
        tomllib.load(f)
    print("TOML 语法合法 OK")
except tomllib.TOMLDecodeError as e:
    print(f"TOML 语法错误:{e}", file=sys.stderr)
    sys.exit(2)
'
  fi
  "$PYTHON_BIN" - "$path" <<< "$py_script"
}

# ---------- 分发 ----------
case "$TYPE" in
  json) check_json "$INPUT_PATH" "$FORMAT" ;;
  yaml) check_yaml "$INPUT_PATH" "$FORMAT" ;;
  toml) check_toml "$INPUT_PATH" "$FORMAT" ;;
  *)
    printf '错误:无法识别文件类型:%s\n' "$FILE" >&2
    exit 1
    ;;
esac
