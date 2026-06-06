#!/usr/bin/env bash
# detect-framework.sh — 嗅探项目目录的测试框架并输出框架名。
# 用法:bash detect-framework.sh [项目目录]
# 输出(stdout):go test | jest | vitest | flutter test | pytest | cargo test | unknown
# 退出码:始终 0(unknown 也算成功)。
set -euo pipefail

DIR="${1:-.}"

if [ ! -d "$DIR" ]; then
  printf 'unknown\n'
  exit 0
fi

# ---- Go ----
if [ -f "$DIR/go.mod" ]; then
  printf 'go test\n'
  exit 0
fi

# ---- Rust ----
if [ -f "$DIR/Cargo.toml" ]; then
  printf 'cargo test\n'
  exit 0
fi

# ---- Flutter / Dart ----
if [ -f "$DIR/pubspec.yaml" ]; then
  printf 'flutter test\n'
  exit 0
fi

# ---- Node.js:vitest 优先于 jest ----
if [ -f "$DIR/package.json" ]; then
  if grep -qiE '"vitest"' "$DIR/package.json"; then
    printf 'vitest\n'
    exit 0
  fi
  if grep -qiE '"jest"' "$DIR/package.json"; then
    printf 'jest\n'
    exit 0
  fi
fi

# ---- Python:pytest(requirements*.txt / pyproject.toml / setup.cfg / setup.py)----
for f in "$DIR/requirements.txt" "$DIR/requirements-dev.txt" "$DIR/requirements_test.txt"; do
  if [ -f "$f" ] && grep -qiE '^pytest' "$f"; then
    printf 'pytest\n'
    exit 0
  fi
done
if [ -f "$DIR/pyproject.toml" ] && grep -qiE 'pytest' "$DIR/pyproject.toml"; then
  printf 'pytest\n'
  exit 0
fi
if [ -f "$DIR/setup.cfg" ] && grep -qiE 'pytest' "$DIR/setup.cfg"; then
  printf 'pytest\n'
  exit 0
fi
if [ -f "$DIR/setup.py" ] && grep -qiE 'pytest' "$DIR/setup.py"; then
  printf 'pytest\n'
  exit 0
fi

printf 'unknown\n'
exit 0
