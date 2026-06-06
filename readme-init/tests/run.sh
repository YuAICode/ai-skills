#!/usr/bin/env bash
# readme-init 测试:构造临时项目目录,断言 scan-project.sh 输出正确。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="$DIR/../bin/scan-project.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

ok() {
  local name="$1"
  local expr="$2"
  if eval "$expr"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"
    fail=$((fail+1))
  fi
}

# ---------- 场景1:Node.js 项目 ----------
echo "== 场景1:Node.js 项目(package.json + src/index.js) =="
NODE_DIR="$TMP/node-proj"
mkdir -p "$NODE_DIR/src"

cat > "$NODE_DIR/package.json" <<'EOF'
{
  "name": "my-app",
  "version": "1.0.0",
  "scripts": {
    "build": "webpack --mode production",
    "test": "jest",
    "start": "node src/index.js"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "webpack": "^5.0.0"
  }
}
EOF
touch "$NODE_DIR/src/index.js"

out1="$(bash "$SCAN" "$NODE_DIR")"

ok "Node: 识别 JavaScript" "printf '%s' \"\$out1\" | grep -q 'JavaScript'"
ok "Node: build 脚本出现" "printf '%s' \"\$out1\" | grep -q 'build'"
ok "Node: test 脚本出现"  "printf '%s' \"\$out1\" | grep -q 'test'"
ok "Node: STRUCTURE 含 src" "printf '%s' \"\$out1\" | grep -qE 'STRUCTURE' && printf '%s' \"\$out1\" | grep -q 'src/'"
ok "Node: ENTRYPOINTS 含 src/index.js" "printf '%s' \"\$out1\" | grep -q 'src/index.js'"
ok "Node: package.json 在 STRUCTURE" "printf '%s' \"\$out1\" | grep -q 'package.json'"

# ---------- 场景2:Go 项目 ----------
echo "== 场景2:Go 项目(go.mod + main.go) =="
GO_DIR="$TMP/go-proj"
mkdir -p "$GO_DIR"
printf 'module example.com/myapp\n\ngo 1.21\n' > "$GO_DIR/go.mod"
touch "$GO_DIR/main.go"

out2="$(bash "$SCAN" "$GO_DIR")"

ok "Go: 识别 Go 语言" "printf '%s' \"\$out2\" | grep -A2 'LANGUAGES' | grep -q 'Go'"
ok "Go: ENTRYPOINTS 含 main.go" "printf '%s' \"\$out2\" | grep -q 'main.go'"
ok "Go: go.mod 在 STRUCTURE" "printf '%s' \"\$out2\" | grep -q 'go.mod'"

# ---------- 场景3:Go + Makefile ----------
echo "== 场景3:Go + Makefile =="
printf 'build:\n\tgo build ./...\n\ntest:\n\tgo test ./...\n\nlint:\n\tgolangci-lint run\n' > "$GO_DIR/Makefile"

out3="$(bash "$SCAN" "$GO_DIR")"

ok "Makefile: build target 出现" "printf '%s' \"\$out3\" | grep -q 'make build'"
ok "Makefile: test target 出现"  "printf '%s' \"\$out3\" | grep -q 'make test'"
ok "Makefile: lint target 出现"  "printf '%s' \"\$out3\" | grep -q 'make lint'"

# ---------- 场景4:Python 项目 ----------
echo "== 场景4:Python 项目(requirements.txt) =="
PY_DIR="$TMP/py-proj"
mkdir -p "$PY_DIR/src"
printf 'flask\nrequests\npytest\n' > "$PY_DIR/requirements.txt"
touch "$PY_DIR/main.py"

out4="$(bash "$SCAN" "$PY_DIR")"

ok "Python: 识别 Python" "printf '%s' \"\$out4\" | grep -q 'Python'"
ok "Python: ENTRYPOINTS 含 main.py" "printf '%s' \"\$out4\" | grep -q 'main.py'"

# ---------- 场景5:Flutter/Dart ----------
echo "== 场景5:Flutter 项目(pubspec.yaml + lib/main.dart) =="
FLUTTER_DIR="$TMP/flutter-proj"
mkdir -p "$FLUTTER_DIR/lib"
printf 'name: my_flutter_app\nversion: 1.0.0\n' > "$FLUTTER_DIR/pubspec.yaml"
touch "$FLUTTER_DIR/lib/main.dart"

out5="$(bash "$SCAN" "$FLUTTER_DIR")"

ok "Flutter: 识别 Flutter/Dart" "printf '%s' \"\$out5\" | grep -q 'Flutter'"
ok "Flutter: ENTRYPOINTS 含 lib/main.dart" "printf '%s' \"\$out5\" | grep -q 'lib/main.dart'"

# ---------- 场景6:Rust ----------
echo "== 场景6:Rust 项目(Cargo.toml + src/main.rs) =="
RUST_DIR="$TMP/rust-proj"
mkdir -p "$RUST_DIR/src"
printf '[package]\nname = "myapp"\nversion = "0.1.0"\nedition = "2021"\n' > "$RUST_DIR/Cargo.toml"
touch "$RUST_DIR/src/main.rs"

out6="$(bash "$SCAN" "$RUST_DIR")"

ok "Rust: 识别 Rust" "printf '%s' \"\$out6\" | grep -q 'Rust'"
ok "Rust: ENTRYPOINTS 含 src/main.rs" "printf '%s' \"\$out6\" | grep -q 'src/main.rs'"

# ---------- 场景7:空目录不崩 ----------
echo "== 场景7:空目录不崩 =="
EMPTY_DIR="$TMP/empty-proj"
mkdir -p "$EMPTY_DIR"

out7="$(bash "$SCAN" "$EMPTY_DIR")"
ok "空目录: 脚本正常退出" "true"
ok "空目录: LANGUAGES=none" "printf '%s' \"\$out7\" | grep -A1 'LANGUAGES' | grep -q 'none'"
ok "空目录: SCRIPTS=none"   "printf '%s' \"\$out7\" | grep -A1 'SCRIPTS'   | grep -q 'none'"
ok "空目录: ENTRYPOINTS=none" "printf '%s' \"\$out7\" | grep -A1 'ENTRYPOINTS' | grep -q 'none'"

# ---------- 场景8:node_modules / .git / dist 被过滤 ----------
echo "== 场景8:噪声目录过滤 =="
mkdir -p "$NODE_DIR/node_modules/lodash" "$NODE_DIR/.git" "$NODE_DIR/dist"

out8="$(bash "$SCAN" "$NODE_DIR")"

ok "噪声过滤: node_modules 不出现在 STRUCTURE" \
  "! (printf '%s' \"\$out8\" | awk '/=== STRUCTURE ===/,0' | grep -q 'node_modules')"
ok "噪声过滤: dist 不出现在 STRUCTURE" \
  "! (printf '%s' \"\$out8\" | awk '/=== STRUCTURE ===/,0' | grep -q 'dist/')"

# ---------- 结果 ----------
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
