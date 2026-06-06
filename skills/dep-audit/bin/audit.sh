#!/usr/bin/env bash
# audit.sh — 扫项目依赖清单,对每个可用生态跑只读的过期检查并输出原始结果。
# 用法:
#   audit.sh [项目目录]   (默认当前目录)
# 环境变量覆盖工具路径(测试/自定义):
#   NPM_CLI     — npm 二进制(默认 npm)
#   GO_CLI      — go 二进制(默认 go)
#   FLUTTER_CLI — flutter 二进制(默认 flutter)
#   PIP_CLI     — pip 二进制(默认 pip)
set -uo pipefail

NPM_CLI="${NPM_CLI:-npm}"
GO_CLI="${GO_CLI:-go}"
FLUTTER_CLI="${FLUTTER_CLI:-flutter}"
PIP_CLI="${PIP_CLI:-pip}"

PROJECT_DIR="${1:-.}"

# 转成绝对路径,确保后续 cd 不受调用位置影响
if command -v realpath >/dev/null 2>&1; then
  PROJECT_DIR="$(realpath "$PROJECT_DIR")"
else
  PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    echo "ERROR: 目录不存在:$1" >&2; exit 1
  }
fi

[ -d "$PROJECT_DIR" ] || { echo "ERROR: 目录不存在:$PROJECT_DIR" >&2; exit 1; }

found=0  # 累计找到的清单数量

# ---------- 辅助函数 ----------

# 检查工具是否可用
has_tool() { command -v "$1" >/dev/null 2>&1; }

# 打印分隔标题
section() { printf '\n=== %s ===\n' "$1"; }

# ---------- npm ----------
if [ -f "$PROJECT_DIR/package.json" ]; then
  found=$((found + 1))
  section "npm (package.json)"
  if has_tool "$NPM_CLI"; then
    # npm outdated 退出码 1 = 有过期包,属正常;其他非零才是真错误
    "$NPM_CLI" outdated --prefix "$PROJECT_DIR" 2>&1 || true
  else
    echo "跳过 npm(未装 $NPM_CLI)"
  fi
fi

# ---------- Go ----------
if [ -f "$PROJECT_DIR/go.mod" ]; then
  found=$((found + 1))
  section "Go (go.mod)"
  if has_tool "$GO_CLI"; then
    (cd "$PROJECT_DIR" && "$GO_CLI" list -m -u all 2>&1) || true
  else
    echo "跳过 Go(未装 $GO_CLI)"
  fi
fi

# ---------- Flutter / Dart ----------
if [ -f "$PROJECT_DIR/pubspec.yaml" ]; then
  found=$((found + 1))
  section "Flutter (pubspec.yaml)"
  if has_tool "$FLUTTER_CLI"; then
    (cd "$PROJECT_DIR" && "$FLUTTER_CLI" pub outdated 2>&1) || true
  else
    echo "跳过 Flutter(未装 $FLUTTER_CLI)"
  fi
fi

# ---------- Python pip ----------
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  found=$((found + 1))
  section "Python pip (requirements.txt)"
  if has_tool "$PIP_CLI"; then
    "$PIP_CLI" list --outdated 2>&1 || true
  else
    echo "跳过 Python pip(未装 $PIP_CLI)"
  fi
fi

# ---------- 没有任何清单 ----------
if [ "$found" -eq 0 ]; then
  echo "未发现依赖清单(未找到 package.json / go.mod / pubspec.yaml / requirements.txt)"
fi
