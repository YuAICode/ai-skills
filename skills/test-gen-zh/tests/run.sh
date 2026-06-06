#!/usr/bin/env bash
# test-gen-zh 测试:造临时项目目录,断言 detect-framework.sh 输出正确框架名。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$DIR/../bin/detect-framework.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# ok <说明> <期望输出> <项目目录>
ok(){
  local name="$1" want="$2" proj="$3"
  local got
  got="$(bash "$DETECT" "$proj")"
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 \"%s\",实际 \"%s\")${NC}\n" "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# ---- Go ----
GO_DIR="$TMP/go_proj"
mkdir -p "$GO_DIR"
printf 'module example.com/demo\n\ngo 1.21\n' > "$GO_DIR/go.mod"
ok "go.mod → go test" "go test" "$GO_DIR"

# ---- Rust ----
RUST_DIR="$TMP/rust_proj"
mkdir -p "$RUST_DIR"
printf '[package]\nname = "demo"\nversion = "0.1.0"\nedition = "2021"\n' > "$RUST_DIR/Cargo.toml"
ok "Cargo.toml → cargo test" "cargo test" "$RUST_DIR"

# ---- Flutter ----
FLUTTER_DIR="$TMP/flutter_proj"
mkdir -p "$FLUTTER_DIR"
printf 'name: demo\nsdkVersion: ">=3.0.0 <4.0.0"\n' > "$FLUTTER_DIR/pubspec.yaml"
ok "pubspec.yaml → flutter test" "flutter test" "$FLUTTER_DIR"

# ---- Jest ----
JEST_DIR="$TMP/jest_proj"
mkdir -p "$JEST_DIR"
printf '{"name":"demo","devDependencies":{"jest":"^29.0.0"}}\n' > "$JEST_DIR/package.json"
ok "package.json 含 jest → jest" "jest" "$JEST_DIR"

# ---- Vitest(优先于 jest 当两者都在)----
VITEST_DIR="$TMP/vitest_proj"
mkdir -p "$VITEST_DIR"
printf '{"name":"demo","devDependencies":{"vitest":"^1.0.0","jest":"^29.0.0"}}\n' > "$VITEST_DIR/package.json"
ok "package.json 含 vitest → vitest(优先)" "vitest" "$VITEST_DIR"

# ---- Vitest 单独 ----
VITEST_ONLY_DIR="$TMP/vitest_only_proj"
mkdir -p "$VITEST_ONLY_DIR"
printf '{"name":"demo","devDependencies":{"vitest":"^1.0.0"}}\n' > "$VITEST_ONLY_DIR/package.json"
ok "package.json 仅含 vitest → vitest" "vitest" "$VITEST_ONLY_DIR"

# ---- Node 但无测试框架 ----
NODE_DIR="$TMP/node_plain"
mkdir -p "$NODE_DIR"
printf '{"name":"demo","dependencies":{"express":"^4.18.0"}}\n' > "$NODE_DIR/package.json"
ok "package.json 无 jest/vitest → unknown" "unknown" "$NODE_DIR"

# ---- pytest via requirements.txt ----
PY_DIR="$TMP/py_proj"
mkdir -p "$PY_DIR"
printf 'pytest>=7.0\nrequests\n' > "$PY_DIR/requirements.txt"
ok "requirements.txt 含 pytest → pytest" "pytest" "$PY_DIR"

# ---- pytest via pyproject.toml ----
PY2_DIR="$TMP/py2_proj"
mkdir -p "$PY2_DIR"
printf '[tool.pytest.ini_options]\ntestpaths = ["tests"]\n' > "$PY2_DIR/pyproject.toml"
ok "pyproject.toml 含 pytest → pytest" "pytest" "$PY2_DIR"

# ---- 空目录 → unknown ----
EMPTY_DIR="$TMP/empty"
mkdir -p "$EMPTY_DIR"
ok "空目录 → unknown" "unknown" "$EMPTY_DIR"

# ---- 不存在的目录 → unknown ----
ok "不存在的目录 → unknown" "unknown" "$TMP/nonexistent"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
