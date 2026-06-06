#!/usr/bin/env bash
# new-skill.sh — 生成一个新 skill 的标准骨架(SKILL.md + README + 可选 bin/tests)
# 用法:
#   new-skill.sh <name> "<中文描述>" [--bin] [--hooks] [--dir <收纳目录>]
#   name 须为 kebab-case;--dir 默认当前目录(在合集仓库根运行)
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
die(){ printf "${RED}❌ %s${NC}\n" "$1" >&2; exit 1; }

NAME=""; DESC=""; WITH_BIN=0; WITH_HOOKS=0; BASE="."
while [ $# -gt 0 ]; do
  case "$1" in
    --bin) WITH_BIN=1; shift;;
    --hooks) WITH_HOOKS=1; WITH_BIN=1; shift;;
    --dir) BASE="$2"; shift 2;;
    -*) die "未知参数:$1";;
    *) if [ -z "$NAME" ]; then NAME="$1"; elif [ -z "$DESC" ]; then DESC="$1"; else die "多余参数:$1"; fi; shift;;
  esac
done

[ -n "$NAME" ] || die "缺 skill 名。用法:new-skill.sh <name> \"<描述>\" [--bin] [--hooks]"
[ -n "$DESC" ] || die "缺描述(用于 SKILL.md 触发与 README)"
printf '%s' "$NAME" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || die "名字须为 kebab-case(小写+连字符):$NAME"

DEST="$BASE/$NAME"
[ -e "$DEST" ] && die "目录已存在:$DEST(不覆盖)"

# 解析 ORG/REPO(支持 SSH / HTTPS;失败给占位符)
ORG="YOUR_ORG"; REPO="YOUR_REPO"
if url="$(git -C "$BASE" remote get-url origin 2>/dev/null)"; then
  slug="$(printf '%s' "$url" | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')"
  case "$slug" in */*) ORG="${slug%%/*}"; REPO="${slug#*/}";; esac
fi
# shields.io 徽章消息转义:- → --,/ → %2F
esc(){ local s="$1"; s="${s//-/--}"; s="${s//\//%2F}"; printf '%s' "$s"; }
BADGE_MSG="$(esc "$ORG/$REPO")"
TREE="https://github.com/$ORG/$REPO/tree/main/$NAME"

mkdir -p "$DEST"

# ---- SKILL.md ----
cat > "$DEST/SKILL.md" <<EOF
---
name: $NAME
description: $DESC
---

# $NAME

> 一句话说清这个 skill 解决什么问题。

## 何时触发

（列出用户会说的话 / 场景,让模型能命中。)

## 用法

（步骤;若有脚本,给出调用方式。)

## 边界

（不做什么 / 依赖 / 限制。)
EOF

# ---- README.md ----
cat > "$DEST/README.md" <<EOF
# $NAME

[![Repo](https://img.shields.io/badge/GitHub-$BADGE_MSG-181717?logo=github)]($TREE)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

$DESC

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

\`\`\`bash
cp -r $NAME ~/.claude/skills/
\`\`\`

## 📖 用法

（补充用法与示例。)

## 📄 License

[MIT](../LICENSE)
EOF

# ---- 可选 bin/ + tests/ ----
if [ "$WITH_BIN" = "1" ]; then
  mkdir -p "$DEST/bin" "$DEST/tests"
  cat > "$DEST/bin/.gitkeep" <<EOF
# 把确定性脚本放这里(纯 bash + 无外部依赖优先)
EOF
  cat > "$DEST/tests/run.sh" <<'EOF'
#!/usr/bin/env bash
# 离线测试:对脚本喂正例/反例,断言退出码。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin"
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
assert(){ local want="$1" name="$2"; shift 3; "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1));
  else printf "${RED}  ✗ %s (期望 %s,实际 %s)${NC}\n" "$name" "$want" "$got"; fail=$((fail+1)); fi; }

# 示例:assert 0 "xxx 放行" -- bash "$BIN/foo.sh" arg

printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
EOF
  chmod 755 "$DEST/tests/run.sh"
fi

if [ "$WITH_HOOKS" = "1" ]; then
  mkdir -p "$DEST/hooks"
  cat > "$DEST/hooks/.gitkeep" <<EOF
# git hook 模板放这里(pre-commit / pre-push 等)
EOF
fi

printf "${GREEN}✅ 已生成 %s${NC}\n" "$DEST"
[ "$WITH_BIN" = "1" ] && echo "   含 bin/ + tests/run.sh 骨架"
[ "$WITH_HOOKS" = "1" ] && echo "   含 hooks/ 骨架"
echo ""
echo "顶层 README 索引表加这一行:"
printf "${YELLOW}| [%s](./%s) | %s | (触发词) |${NC}\n" "$NAME" "$NAME" "${DESC%%。*}"
