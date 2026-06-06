#!/usr/bin/env bash
# dep-audit 测试:用 stub 工具验证各生态扫描和降级行为,不依赖真实包管理器。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$DIR/../bin/audit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# ok <描述> <条件表达式(eval)>
ok(){
  local name="$1" expr="$2"
  if eval "$expr"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"; fail=$((fail+1))
  fi
}

# ---------- Stub 工具目录 ----------
STUBS="$TMP/stubs"
mkdir -p "$STUBS"

# stub npm:输出固定 outdated 文本,退出码 1(npm outdated 有过期包时惯例)
cat > "$STUBS/npm" <<'EOF'
#!/bin/sh
echo "Package          Current  Wanted  Latest  Location"
echo "lodash            4.17.0  4.17.21  4.17.21  node_modules/lodash"
echo "express            4.17.0   4.18.2   5.0.0  node_modules/express"
exit 1
EOF
chmod +x "$STUBS/npm"

# stub go:输出 go list -m -u all 风格文本
cat > "$STUBS/go" <<'EOF'
#!/bin/sh
echo "github.com/gin-gonic/gin v1.9.0 [v1.9.1]"
echo "github.com/stretchr/testify v1.8.0 [v1.9.0]"
exit 0
EOF
chmod +x "$STUBS/go"

# stub flutter:输出 flutter pub outdated 风格文本
cat > "$STUBS/flutter" <<'EOF'
#!/bin/sh
echo "Showing outdated packages."
echo "http: 0.13.4 -> 0.13.6 (latest: 1.2.0)"
exit 0
EOF
chmod +x "$STUBS/flutter"

# stub pip:输出 pip list --outdated 风格文本
cat > "$STUBS/pip" <<'EOF'
#!/bin/sh
echo "Package    Version Latest Type"
echo "requests   2.28.0  2.31.0 wheel"
exit 0
EOF
chmod +x "$STUBS/pip"

# ---------- 辅助:跑 audit.sh 并捕获输出 ----------
run_audit(){
  # 参数: [env_prefix_vars] <project_dir>
  # 环境变量通过调用方设置后 bash 继承
  bash "$AUDIT" "$@" 2>&1
}

# ============================================================
# 测试 1:npm 生态 — stub 调用到且输出包含期待内容
# ============================================================
echo "== npm 生态 =="
NPM_DIR="$TMP/npm_proj"
mkdir -p "$NPM_DIR"
echo '{"name":"test"}' > "$NPM_DIR/package.json"

out="$(NPM_CLI="$STUBS/npm" GO_CLI=/nonexistent/go FLUTTER_CLI=/nonexistent/flutter PIP_CLI=/nonexistent/pip bash "$AUDIT" "$NPM_DIR")"
ok "npm 节标题出现" "printf '%s' \"\$out\" | grep -q 'npm (package.json)'"
ok "npm stub 输出:含 lodash" "printf '%s' \"\$out\" | grep -q 'lodash'"
ok "npm stub 输出:含 express" "printf '%s' \"\$out\" | grep -q 'express'"

# ============================================================
# 测试 2:Go 生态
# ============================================================
echo "== Go 生态 =="
GO_DIR="$TMP/go_proj"
mkdir -p "$GO_DIR"
echo 'module example.com/test' > "$GO_DIR/go.mod"

out2="$(NPM_CLI=/nonexistent/npm GO_CLI="$STUBS/go" FLUTTER_CLI=/nonexistent/flutter PIP_CLI=/nonexistent/pip bash "$AUDIT" "$GO_DIR")"
ok "go 节标题出现" "printf '%s' \"\$out2\" | grep -q 'Go (go.mod)'"
ok "go stub 输出:含 gin" "printf '%s' \"\$out2\" | grep -q 'gin-gonic'"

# ============================================================
# 测试 3:Flutter 生态
# ============================================================
echo "== Flutter 生态 =="
FL_DIR="$TMP/fl_proj"
mkdir -p "$FL_DIR"
echo 'name: myapp' > "$FL_DIR/pubspec.yaml"

out3="$(NPM_CLI=/nonexistent/npm GO_CLI=/nonexistent/go FLUTTER_CLI="$STUBS/flutter" PIP_CLI=/nonexistent/pip bash "$AUDIT" "$FL_DIR")"
ok "flutter 节标题出现" "printf '%s' \"\$out3\" | grep -q 'Flutter (pubspec.yaml)'"
ok "flutter stub 输出:含 http" "printf '%s' \"\$out3\" | grep -q 'http'"

# ============================================================
# 测试 4:Python pip 生态
# ============================================================
echo "== Python pip 生态 =="
PY_DIR="$TMP/py_proj"
mkdir -p "$PY_DIR"
echo 'requests==2.28.0' > "$PY_DIR/requirements.txt"

out4="$(NPM_CLI=/nonexistent/npm GO_CLI=/nonexistent/go FLUTTER_CLI=/nonexistent/flutter PIP_CLI="$STUBS/pip" bash "$AUDIT" "$PY_DIR")"
ok "pip 节标题出现" "printf '%s' \"\$out4\" | grep -q 'Python pip (requirements.txt)'"
ok "pip stub 输出:含 requests" "printf '%s' \"\$out4\" | grep -q 'requests'"

# ============================================================
# 测试 5:工具不可用时跳过且不崩(exit 0)
# ============================================================
echo "== 工具不可用时跳过 =="
SKIP_DIR="$TMP/skip_proj"
mkdir -p "$SKIP_DIR"
echo '{"name":"test"}' > "$SKIP_DIR/package.json"
echo 'module example.com/test' > "$SKIP_DIR/go.mod"
echo 'name: myapp' > "$SKIP_DIR/pubspec.yaml"
echo 'requests==2.28.0' > "$SKIP_DIR/requirements.txt"

skip_out="$(NPM_CLI=/nonexistent/npm GO_CLI=/nonexistent/go FLUTTER_CLI=/nonexistent/flutter PIP_CLI=/nonexistent/pip bash "$AUDIT" "$SKIP_DIR")"
skip_exit=$?
ok "工具全不可用时退出码为 0" "[ \"$skip_exit\" -eq 0 ]"
ok "npm 跳过提示出现" "printf '%s' \"\$skip_out\" | grep -q '跳过 npm'"
ok "Go 跳过提示出现" "printf '%s' \"\$skip_out\" | grep -q '跳过 Go'"
ok "Flutter 跳过提示出现" "printf '%s' \"\$skip_out\" | grep -q '跳过 Flutter'"
ok "pip 跳过提示出现" "printf '%s' \"\$skip_out\" | grep -q '跳过 Python pip'"

# ============================================================
# 测试 6:空目录 — 无清单,提示"未发现依赖清单"
# ============================================================
echo "== 空目录无清单 =="
EMPTY_DIR="$TMP/empty_proj"
mkdir -p "$EMPTY_DIR"

empty_out="$(bash "$AUDIT" "$EMPTY_DIR" 2>&1)"
empty_exit=$?
ok "空目录退出码为 0" "[ \"$empty_exit\" -eq 0 ]"
ok "空目录提示未发现清单" "printf '%s' \"\$empty_out\" | grep -q '未发现依赖清单'"

# ============================================================
# 测试 7:多清单并存时全部识别
# ============================================================
echo "== 多清单并存 =="
MULTI_DIR="$TMP/multi_proj"
mkdir -p "$MULTI_DIR"
echo '{"name":"test"}' > "$MULTI_DIR/package.json"
echo 'module example.com/test' > "$MULTI_DIR/go.mod"

multi_out="$(NPM_CLI="$STUBS/npm" GO_CLI="$STUBS/go" FLUTTER_CLI=/nonexistent/flutter PIP_CLI=/nonexistent/pip bash "$AUDIT" "$MULTI_DIR")"
ok "多清单:npm 节存在" "printf '%s' \"\$multi_out\" | grep -q 'npm (package.json)'"
ok "多清单:go 节存在" "printf '%s' \"\$multi_out\" | grep -q 'Go (go.mod)'"

# ============================================================
# 测试 8:目录不存在时报错并退出非 0
# ============================================================
echo "== 目录不存在 =="
bad_exit=0
bash "$AUDIT" "/nonexistent/no/such/path" >/dev/null 2>&1 || bad_exit=$?
ok "不存在目录退出码非 0" "[ \"$bad_exit\" -ne 0 ]"

# ============================================================
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
