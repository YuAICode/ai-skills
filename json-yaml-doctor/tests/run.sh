#!/usr/bin/env bash
# json-yaml-doctor 测试:造合法/非法样本文件,验证退出码与中文报错。
# 不依赖网络;YAML 用例根据 pyyaml 是否安装做分支断言。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$DIR/../bin/check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# --- 辅助函数 ---
ok() {
  local name="$1"; shift
  if eval "$@"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"; fail=$((fail+1))
  fi
}

# 断言退出码
assert_exit() {
  local want="$1" name="$2"; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 exit %s,实际 %s)${NC}\n" "$name" "$want" "$got"; fail=$((fail+1))
  fi
}

# 断言输出含特定字符串(stdout+stderr 合并)
assert_contains() {
  local pattern="$1" name="$2"; shift 2
  local out
  out="$("$@" 2>&1 || true)"
  if printf '%s' "$out" | grep -q "$pattern"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (未找到 \"%s\" in: %s)${NC}\n" "$name" "$pattern" "$out"; fail=$((fail+1))
  fi
}

# ============================================================
# 1. JSON — 合法
# ============================================================
echo "== JSON 合法 =="
printf '{"name":"alice","age":30}' > "$TMP/ok.json"

assert_exit 0 "合法 JSON exit 0" bash "$CHECK" "$TMP/ok.json"
assert_contains "OK" "合法 JSON 输出含 OK" bash "$CHECK" "$TMP/ok.json"

# --format 输出美化内容(应含换行缩进)
fmt_out="$(bash "$CHECK" "$TMP/ok.json" --format 2>&1)"
assert_exit 0 "合法 JSON --format exit 0" bash "$CHECK" "$TMP/ok.json" --format
ok "--format 输出含键名 name" "printf '%s' \"\$fmt_out\" | grep -q '\"name\"'"
ok "--format 输出含键名 age"  "printf '%s' \"\$fmt_out\" | grep -q '\"age\"'"

# ============================================================
# 2. JSON — 尾逗号(非法)
# ============================================================
echo "== JSON 尾逗号(非法) =="
printf '{"key":"value","extra":1,}' > "$TMP/trailing.json"

assert_exit 2 "尾逗号 JSON exit 2" bash "$CHECK" "$TMP/trailing.json"
assert_contains "语法错误" "尾逗号 JSON 输出含中文「语法错误」" bash "$CHECK" "$TMP/trailing.json"
assert_contains "行" "尾逗号报错含「行」定位" bash "$CHECK" "$TMP/trailing.json"

# ============================================================
# 3. JSON — 多行,错误在第 3 行
# ============================================================
echo "== JSON 多行错误定位 =="
cat > "$TMP/multiline.json" <<'EOF'
{
  "a": 1,
  "b": 2
  "c": 3
}
EOF
assert_exit 2 "多行 JSON 缺逗号 exit 2" bash "$CHECK" "$TMP/multiline.json"
# 应该报出行号(不要求具体行数,只要含数字)
err_out="$(bash "$CHECK" "$TMP/multiline.json" 2>&1 || true)"
ok "多行 JSON 报错含行号数字" "printf '%s' \"\$err_out\" | grep -qE '第 [0-9]+ 行'"

# ============================================================
# 4. JSON stdin (-)
# ============================================================
echo "== JSON stdin =="
assert_exit 0 "合法 JSON 从 stdin exit 0" bash -c "printf '{\"x\":1}' | bash \"$CHECK\" -"
assert_exit 2 "非法 JSON 从 stdin exit 2" bash -c "printf '{bad json}' | bash \"$CHECK\" -"

# ============================================================
# 5. 文件不存在
# ============================================================
echo "== 防御 =="
assert_exit 1 "文件不存在 exit 1" bash "$CHECK" "$TMP/nonexistent.json"

# ============================================================
# 6. YAML — 根据 pyyaml 安装情况分支断言
# ============================================================
echo "== YAML =="
HAS_YAML=0
python3 -c 'import yaml' 2>/dev/null && HAS_YAML=1

if [ "$HAS_YAML" = "1" ]; then
  echo "   (pyyaml 已安装 — 测合法/非法)"

  # 合法 YAML
  cat > "$TMP/ok.yaml" <<'EOF'
name: alice
age: 30
tags:
  - admin
  - user
EOF
  assert_exit 0 "合法 YAML exit 0" bash "$CHECK" "$TMP/ok.yaml"
  assert_contains "OK" "合法 YAML 输出含 OK" bash "$CHECK" "$TMP/ok.yaml"

  # --format
  assert_exit 0 "合法 YAML --format exit 0" bash "$CHECK" "$TMP/ok.yaml" --format

  # 非法 YAML:Tab 缩进
  printf 'key: value\n\tchild: bad' > "$TMP/tab.yaml"
  assert_exit 2 "Tab 缩进 YAML exit 2" bash "$CHECK" "$TMP/tab.yaml"
  assert_contains "语法错误" "Tab YAML 输出含中文「语法错误」" bash "$CHECK" "$TMP/tab.yaml"

  # 非法 YAML:.yml 扩展名也识别
  printf 'key: :\n  broken' > "$TMP/broken.yml"
  assert_exit 2 ".yml 扩展名非法 exit 2" bash "$CHECK" "$TMP/broken.yml"

else
  echo "   (pyyaml 未安装 — 断言优雅提示且 exit 0)"

  printf 'key: value\n' > "$TMP/ok.yaml"
  assert_exit 0 "无 pyyaml 时 exit 0(跳过)" bash "$CHECK" "$TMP/ok.yaml"
  assert_contains "pip install pyyaml" "无 pyyaml 时提示安装命令" bash "$CHECK" "$TMP/ok.yaml"
fi

# ============================================================
# 7. TOML — 根据 tomllib 安装情况分支断言
# ============================================================
echo "== TOML =="
HAS_TOML=0
python3 -c 'import tomllib' 2>/dev/null && HAS_TOML=1

if [ "$HAS_TOML" = "1" ]; then
  echo "   (tomllib 可用 — 测合法/非法)"

  cat > "$TMP/ok.toml" <<'EOF'
[server]
host = "localhost"
port = 8080
EOF
  assert_exit 0 "合法 TOML exit 0" bash "$CHECK" "$TMP/ok.toml"
  assert_contains "OK" "合法 TOML 输出含 OK" bash "$CHECK" "$TMP/ok.toml"

  # 非法 TOML:键重复
  cat > "$TMP/dup.toml" <<'EOF'
key = "first"
key = "second"
EOF
  assert_exit 2 "重复键 TOML exit 2" bash "$CHECK" "$TMP/dup.toml"
  assert_contains "语法错误" "重复键 TOML 输出含中文「语法错误」" bash "$CHECK" "$TMP/dup.toml"

else
  echo "   (tomllib 不可用 — 断言优雅提示且 exit 0)"

  printf '[server]\nhost = "localhost"\n' > "$TMP/ok.toml"
  assert_exit 0 "无 tomllib 时 exit 0(跳过)" bash "$CHECK" "$TMP/ok.toml"
  assert_contains "Python 3.11" "无 tomllib 时提示升级 Python" bash "$CHECK" "$TMP/ok.toml"
fi

# ============================================================
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
