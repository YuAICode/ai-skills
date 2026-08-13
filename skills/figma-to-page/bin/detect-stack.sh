#!/usr/bin/env bash
# detect-stack.sh — 探测宿主项目的技术栈、design token 层位置、以及可用的截图手段。
# 用法: detect-stack.sh [项目根目录]   (默认当前目录)
# 退出码: 0=完成探测(信息性,永远不因"没探到"而失败) / 1=目录无效
#
# 这是启发式探测。探不到不等于不存在,Claude 应结合实际项目结构判断,
# 不要凭本脚本的结论断言"项目没有 token 层"。
set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'

ROOT="${1:-.}"
if [ ! -d "$ROOT" ]; then
  printf "错误: 目录不存在: %s\n" "$ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

# ------------------------------------------------------------------
# 工具函数
# ------------------------------------------------------------------
# 在项目内查找文件,跳过依赖/构建目录,限制深度以免大仓库卡住
findp() {
  local pattern="$1" depth="${2:-4}"
  find "$ROOT" -maxdepth "$depth" \
    \( -path '*/node_modules' -o -path '*/.git' -o -path '*/build' \
       -o -path '*/.dart_tool' -o -path '*/Pods' -o -path '*/vendor' \
       -o -path '*/dist' -o -path '*/.next' \) -prune -o \
    -name "$pattern" -type f -print 2>/dev/null | head -20
}

has_file() { [ -f "$ROOT/$1" ]; }

# 在 package.json 里找依赖名(不依赖 jq)
pkg_has() {
  has_file package.json || return 1
  grep -qE "\"$1\"[[:space:]]*:" "$ROOT/package.json" 2>/dev/null
}

rel() { printf '%s' "${1#$ROOT/}"; }

STACK="unknown"
STACK_DETAIL=""
TOKEN_FILES=()
TOKEN_STATUS="missing"
SHOT_METHODS=()

# ------------------------------------------------------------------
# 1) 技术栈判定
# ------------------------------------------------------------------
if has_file pubspec.yaml && grep -qE '^[[:space:]]*flutter:' "$ROOT/pubspec.yaml" 2>/dev/null; then
  STACK="flutter"
  STACK_DETAIL="pubspec.yaml 含 flutter 依赖"
elif has_file package.json; then
  if pkg_has next; then
    STACK="next"; STACK_DETAIL="package.json 含 next"
  elif pkg_has "react-native"; then
    STACK="react-native"; STACK_DETAIL="package.json 含 react-native"
  elif pkg_has react; then
    STACK="react"; STACK_DETAIL="package.json 含 react"
  elif pkg_has vue; then
    STACK="vue"; STACK_DETAIL="package.json 含 vue"
  elif pkg_has svelte; then
    STACK="svelte"; STACK_DETAIL="package.json 含 svelte"
  else
    STACK="web-js"; STACK_DETAIL="有 package.json,未识别具体框架"
  fi
elif [ -n "$(find "$ROOT" -maxdepth 2 -name '*.xcodeproj' -o -maxdepth 2 -name '*.xcworkspace' 2>/dev/null | head -1)" ]; then
  STACK="ios-native"
  STACK_DETAIL="发现 xcodeproj/xcworkspace"
elif has_file build.gradle || has_file build.gradle.kts || has_file settings.gradle; then
  STACK="android-native"
  STACK_DETAIL="发现 gradle 构建文件"
elif [ -n "$(findp '*.html' 2)" ]; then
  STACK="static-html"
  STACK_DETAIL="发现 html 文件,无包管理器"
fi

# Tailwind 是叠加信息,不是独立栈
TAILWIND_CONFIG=""
for c in tailwind.config.js tailwind.config.ts tailwind.config.cjs tailwind.config.mjs; do
  if has_file "$c"; then TAILWIND_CONFIG="$c"; break; fi
done

# ------------------------------------------------------------------
# 2) design token / theme 层定位
# ------------------------------------------------------------------
case "$STACK" in
  flutter)
    # 优先找专门的 theme/token 文件,其次找 ThemeData 定义处
    while IFS= read -r f; do
      [ -n "$f" ] && TOKEN_FILES+=("$(rel "$f")")
    done < <(find "$ROOT/lib" -maxdepth 5 \
               \( -iname 'theme*.dart' -o -iname '*_theme.dart' -o -iname 'colors*.dart' \
                  -o -iname 'app_colors*.dart' -o -iname 'app_text*.dart' \
                  -o -iname 'spacing*.dart' -o -iname 'tokens*.dart' -o -iname 'design_token*.dart' \) \
               -type f -print 2>/dev/null | head -10)
    if [ "${#TOKEN_FILES[@]}" -eq 0 ]; then
      while IFS= read -r f; do
        [ -n "$f" ] && TOKEN_FILES+=("$(rel "$f") (含 ThemeData)")
      done < <(grep -rl 'ThemeData(' "$ROOT/lib" --include='*.dart' 2>/dev/null | head -5)
    fi
    ;;
  next|react|vue|svelte|web-js|static-html|react-native)
    if [ -n "$TAILWIND_CONFIG" ]; then
      if grep -qE 'theme[[:space:]]*:' "$ROOT/$TAILWIND_CONFIG" 2>/dev/null; then
        TOKEN_FILES+=("$TAILWIND_CONFIG (tailwind theme)")
      fi
    fi
    # CSS 自定义属性
    while IFS= read -r f; do
      [ -n "$f" ] && grep -qE '^\s*--[a-zA-Z]' "$f" 2>/dev/null && TOKEN_FILES+=("$(rel "$f") (CSS 变量)")
    done < <(findp '*.css' 4)
    # JS/TS theme 模块
    while IFS= read -r f; do
      [ -n "$f" ] && TOKEN_FILES+=("$(rel "$f")")
    done < <(find "$ROOT" -maxdepth 5 \
               \( -path '*/node_modules' -o -path '*/.git' -o -path '*/dist' -o -path '*/.next' \) -prune -o \
               \( -iname 'theme.ts' -o -iname 'theme.js' -o -iname 'tokens.ts' -o -iname 'tokens.js' \
                  -o -iname 'design-tokens.*' \) -type f -print 2>/dev/null | head -10)
    ;;
  ios-native)
    while IFS= read -r f; do
      [ -n "$f" ] && TOKEN_FILES+=("$(rel "$f")")
    done < <(find "$ROOT" -maxdepth 5 -path '*/Pods' -prune -o \
               \( -iname '*Theme*.swift' -o -iname '*Color*.swift' -o -iname '*Token*.swift' \) \
               -type f -print 2>/dev/null | head -10)
    ;;
esac

# 去重(不用 mapfile —— macOS 自带 bash 3.2 没有这个 builtin)
if [ "${#TOKEN_FILES[@]}" -gt 0 ]; then
  _dedup=()
  while IFS= read -r line; do
    [ -n "$line" ] && _dedup+=("$line")
  done < <(printf '%s\n' "${TOKEN_FILES[@]}" | awk '!seen[$0]++')
  TOKEN_FILES=("${_dedup[@]}")
  TOKEN_STATUS="found"
fi

# ------------------------------------------------------------------
# 3) 截图能力探测(按优先级)
# ------------------------------------------------------------------
# 3.1 项目内 run 脚本
while IFS= read -r f; do
  [ -n "$f" ] && SHOT_METHODS+=("项目脚本: $(rel "$f")")
done < <(find "$ROOT/scripts" -maxdepth 2 \
           \( -iname 'run_app*' -o -iname 'run-app*' -o -iname '*hot_reload*' -o -iname 'dev.sh' \) \
           -type f -print 2>/dev/null | head -8)

# 3.2 package.json dev/start script
if has_file package.json && grep -qE '"(dev|start)"[[:space:]]*:' "$ROOT/package.json" 2>/dev/null; then
  SHOT_METHODS+=("package.json 的 dev/start script(配合无头浏览器截图)")
fi

# 3.3 gstack browse(web 无头浏览器)
if command -v gstack >/dev/null 2>&1 || [ -d "$HOME/.claude/skills/browse" ]; then
  SHOT_METHODS+=("gstack /browse 无头浏览器(适用 web)")
fi

# 3.4 iOS 模拟器
if command -v xcrun >/dev/null 2>&1 && xcrun simctl help >/dev/null 2>&1; then
  SHOT_METHODS+=("xcrun simctl io booted screenshot(iOS 模拟器)")
fi
if [ -d "$HOME/.claude/skills/ios-qa" ]; then
  SHOT_METHODS+=("gstack /ios-qa(iOS 真机/模拟器)")
fi

# 3.5 Android 模拟器
if command -v adb >/dev/null 2>&1; then
  SHOT_METHODS+=("adb exec-out screencap(Android)")
fi

# ------------------------------------------------------------------
# 4) Pillow(pixdiff 依赖)
# ------------------------------------------------------------------
PILLOW="missing"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import PIL' >/dev/null 2>&1; then
  PILLOW="ok"
fi

# ------------------------------------------------------------------
# 输出
# ------------------------------------------------------------------
printf "${BLUE}[figma-to-page] 阶段 0 · 项目能力探测${NC}\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "项目根目录  : %s\n" "$ROOT"
printf "技术栈      : %s" "$STACK"
[ -n "$STACK_DETAIL" ] && printf "  (%s)" "$STACK_DETAIL"
printf "\n"
[ -n "$TAILWIND_CONFIG" ] && printf "Tailwind    : %s\n" "$TAILWIND_CONFIG"
printf "\n"

printf "── design token 层 ──\n"
if [ "$TOKEN_STATUS" = "found" ]; then
  printf "${GREEN}✓ 找到候选 token/theme 文件:${NC}\n"
  for f in "${TOKEN_FILES[@]}"; do printf "    %s\n" "$f"; done
  printf "  → 阶段 2 应把 Figma 变量映射到这些文件里,缺的变量补进去。\n"
else
  printf "${YELLOW}⚠ 未找到 token/theme 层。${NC}\n"
  printf "  → 按设计决策:阶段 2 应「主动建立」一个 token 层,而不是在页面里硬编码色值/字号。\n"
fi
printf "\n"

printf "── 截图手段(阶段 4 闭环所需)──\n"
if [ "${#SHOT_METHODS[@]}" -gt 0 ]; then
  printf "${GREEN}✓ 可用手段(按上下顺序优先尝试):${NC}\n"
  for m in "${SHOT_METHODS[@]}"; do printf "    %s\n" "$m"; done
else
  printf "${YELLOW}⚠ 未探测到任何自动截图手段。${NC}\n"
  printf "  → 降级:需用户手动提供实现页面的截图。必须明确告知用户原因,不要静默跳过校验。\n"
fi
printf "\n"

printf "── pixdiff 依赖 ──\n"
if [ "$PILLOW" = "ok" ]; then
  printf "${GREEN}✓ Pillow 可用,阶段 4 走量化像素 diff${NC}\n"
else
  printf "${YELLOW}⚠ 缺 Pillow(python3 -m pip install Pillow)${NC}\n"
  printf "  → 降级为模型肉眼对比:无量化阈值,需人工判断收敛。\n"
fi

exit 0
