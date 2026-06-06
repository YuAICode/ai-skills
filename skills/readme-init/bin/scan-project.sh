#!/usr/bin/env bash
# scan-project.sh — 扫描项目目录,输出结构化事实供 Claude 撰写 README。
# 用法:bash scan-project.sh [项目目录,默认当前目录]
# 输出段落:LANGUAGES / SCRIPTS / ENTRYPOINTS / STRUCTURE
# 退出码:始终 0(空目录也安全)。
# 依赖:纯 bash 3.2+ + grep + awk;无需外部工具。
set -uo pipefail

DIR="${1:-.}"

if [ ! -d "$DIR" ]; then
  printf 'ERROR: 目录不存在:%s\n' "$DIR" >&2
  exit 1
fi

# ---------- 辅助函数 ----------

# 追加语言到已发现列表(去重)
LANGUAGES_LIST=""
add_lang() {
  local lang="$1"
  case "$LANGUAGES_LIST" in
    *"$lang"*) ;;  # 已存在,跳过
    *) LANGUAGES_LIST="${LANGUAGES_LIST:+$LANGUAGES_LIST, }$lang" ;;
  esac
}

SCRIPTS_LIST=""
add_script() {
  local entry="$1"
  SCRIPTS_LIST="${SCRIPTS_LIST:+$SCRIPTS_LIST\n}  - $entry"
}

ENTRYPOINTS_LIST=""
add_entry() {
  local path="$1"
  ENTRYPOINTS_LIST="${ENTRYPOINTS_LIST:+$ENTRYPOINTS_LIST\n}  - $path"
}

# ---------- LANGUAGES 检测 ----------

# Go
[ -f "$DIR/go.mod" ] && add_lang "Go"

# Node.js / JavaScript / TypeScript
if [ -f "$DIR/package.json" ]; then
  if grep -qE '"typescript"|"ts-node"|"@types/' "$DIR/package.json" 2>/dev/null; then
    add_lang "TypeScript"
  else
    add_lang "JavaScript (Node.js)"
  fi
fi

# Flutter / Dart
[ -f "$DIR/pubspec.yaml" ] && add_lang "Flutter/Dart"

# Rust
[ -f "$DIR/Cargo.toml" ] && add_lang "Rust"

# Python
for _f in "$DIR/requirements.txt" "$DIR/requirements-dev.txt" "$DIR/pyproject.toml" "$DIR/setup.py" "$DIR/setup.cfg"; do
  if [ -f "$_f" ]; then
    add_lang "Python"
    break
  fi
done

# Ruby
[ -f "$DIR/Gemfile" ] && add_lang "Ruby"

# Java / Kotlin (Maven / Gradle)
if [ -f "$DIR/pom.xml" ]; then
  add_lang "Java (Maven)"
fi
if [ -f "$DIR/build.gradle" ] || [ -f "$DIR/build.gradle.kts" ]; then
  if grep -qiE 'kotlin' "$DIR/build.gradle" 2>/dev/null || [ -f "$DIR/build.gradle.kts" ]; then
    add_lang "Kotlin (Gradle)"
  else
    add_lang "Java (Gradle)"
  fi
fi

# PHP / Composer
[ -f "$DIR/composer.json" ] && add_lang "PHP"

# Swift / Package.swift
[ -f "$DIR/Package.swift" ] && add_lang "Swift"

# 兜底:靠文件扩展名粗判(只有上面均未命中时才扫)
if [ -z "$LANGUAGES_LIST" ]; then
  _py_cnt=$(find "$DIR" -maxdepth 3 -name "*.py" 2>/dev/null | head -1)
  _js_cnt=$(find "$DIR" -maxdepth 3 -name "*.js" 2>/dev/null | head -1)
  _ts_cnt=$(find "$DIR" -maxdepth 3 -name "*.ts" 2>/dev/null | head -1)
  _go_cnt=$(find "$DIR" -maxdepth 3 -name "*.go" 2>/dev/null | head -1)
  _rb_cnt=$(find "$DIR" -maxdepth 3 -name "*.rb" 2>/dev/null | head -1)
  [ -n "$_py_cnt" ] && add_lang "Python"
  [ -n "$_ts_cnt" ] && add_lang "TypeScript"
  [ -n "$_js_cnt" ] && [ -z "$_ts_cnt" ] && add_lang "JavaScript"
  [ -n "$_go_cnt" ] && add_lang "Go"
  [ -n "$_rb_cnt" ] && add_lang "Ruby"
fi

# ---------- SCRIPTS 提取 ----------

# package.json scripts
if [ -f "$DIR/package.json" ]; then
  # 用 grep+awk 兼容 bash 3.2,无需 jq
  # 提取 "scripts": { ... } 块中的 "key": "value" 行
  _in_scripts=0
  while IFS= read -r _line; do
    case "$_line" in
      *'"scripts"'*'{'*)
        _in_scripts=1
        ;;
    esac
    if [ "$_in_scripts" = "1" ]; then
      case "$_line" in
        *'}'*) _in_scripts=0; break ;;
        *':'*)
          # 提取形如 "key": "value" 的行
          _key=$(printf '%s' "$_line" | grep -oE '"[^"]+":' | head -1 | tr -d '":')
          _val=$(printf '%s' "$_line" | sed 's/.*": *"//' | sed 's/"[^"]*$//')
          if [ -n "$_key" ] && [ "$_key" != "scripts" ]; then
            add_script "npm run $_key  →  $_val"
          fi
          ;;
      esac
    fi
  done < "$DIR/package.json"
fi

# Makefile targets
if [ -f "$DIR/Makefile" ]; then
  while IFS= read -r _line; do
    case "$_line" in
      \#*) continue ;;
      *:*)
        _target=$(printf '%s' "$_line" | grep -oE '^[a-zA-Z0-9_%-]+')
        if [ -n "$_target" ]; then
          add_script "make $_target"
        fi
        ;;
    esac
  done < "$DIR/Makefile"
fi

# composer.json scripts
if [ -f "$DIR/composer.json" ]; then
  _in_scripts=0
  while IFS= read -r _line; do
    case "$_line" in
      *'"scripts"'*'{'*) _in_scripts=1 ;;
    esac
    if [ "$_in_scripts" = "1" ]; then
      case "$_line" in
        *'}'*) _in_scripts=0; break ;;
        *':'*)
          _key=$(printf '%s' "$_line" | grep -oE '"[^"]+":' | head -1 | tr -d '":')
          if [ -n "$_key" ] && [ "$_key" != "scripts" ]; then
            add_script "composer run-script $_key"
          fi
          ;;
      esac
    fi
  done < "$DIR/composer.json"
fi

# ---------- ENTRYPOINTS ----------

for _ep in \
  "main.go" \
  "cmd/main.go" \
  "src/index.js" \
  "src/index.ts" \
  "index.js" \
  "index.ts" \
  "main.py" \
  "app.py" \
  "src/main.py" \
  "lib/main.dart" \
  "src/main.rs" \
  "main.rb" \
  "app/main.swift" \
  "Sources/main.swift" \
  "src/Main.java" \
  "src/main/java/Main.java" \
; do
  [ -f "$DIR/$_ep" ] && add_entry "$_ep"
done

# ---------- STRUCTURE(顶层目录,排除常见噪声) ----------

STRUCTURE_LIST=""
_ignore="node_modules|^\.git$|^dist$|^build$|^\.build$|^__pycache__$|^\.dart_tool$|^\.idea$|^\.vscode$|^target$|^vendor$|^\.cache$|^coverage$|^\.nyc_output$"

while IFS= read -r _entry; do
  _name=$(basename "$_entry")
  # 过滤隐藏目录(以 . 开头)和噪声目录
  case "$_name" in
    .*) continue ;;
  esac
  if printf '%s' "$_name" | grep -qE "$_ignore"; then
    continue
  fi
  STRUCTURE_LIST="${STRUCTURE_LIST:+$STRUCTURE_LIST\n}  - $_name/"
done < <(find "$DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

# 也列顶层文件(仅重要的配置/入口文件)
while IFS= read -r _entry; do
  _name=$(basename "$_entry")
  case "$_name" in
    Makefile|Dockerfile|docker-compose.yml|docker-compose.yaml|\
    go.mod|package.json|Cargo.toml|pubspec.yaml|pom.xml|\
    composer.json|Gemfile|Package.swift|pyproject.toml|\
    requirements.txt|README.md|LICENSE)
      STRUCTURE_LIST="${STRUCTURE_LIST:+$STRUCTURE_LIST\n}  - $_name"
      ;;
  esac
done < <(find "$DIR" -maxdepth 1 -mindepth 1 -type f 2>/dev/null | sort)

# ---------- 输出 ----------

printf '=== LANGUAGES ===\n'
if [ -n "$LANGUAGES_LIST" ]; then
  printf '  %s\n' "$LANGUAGES_LIST"
else
  printf '  none\n'
fi

printf '\n=== SCRIPTS ===\n'
if [ -n "$SCRIPTS_LIST" ]; then
  printf "$SCRIPTS_LIST\n"
else
  printf '  none\n'
fi

printf '\n=== ENTRYPOINTS ===\n'
if [ -n "$ENTRYPOINTS_LIST" ]; then
  printf "$ENTRYPOINTS_LIST\n"
else
  printf '  none\n'
fi

printf '\n=== STRUCTURE ===\n'
if [ -n "$STRUCTURE_LIST" ]; then
  printf "$STRUCTURE_LIST\n"
else
  printf '  (空目录)\n'
fi
