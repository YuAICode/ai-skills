#!/usr/bin/env bash
# claude-code-zh 安装脚本
# 作用:① 让 Claude Code 默认用中文回复  ② 安装命令中文 tooltip hook
# 所有改动可逆:CLAUDE.md 用 sentinel 标记包裹,settings.json 安装前自动备份。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
say() { printf "${CYAN}%s${NC}\n" "$1"; }
ok()  { printf "${GREEN}✅ %s${NC}\n" "$1"; }
warn(){ printf "${YELLOW}⚠️  %s${NC}\n" "$1"; }

command -v python3 >/dev/null 2>&1 || { echo "需要 python3 来安全修改 settings.json"; exit 1; }

say "🌸 安装 claude-code-zh 到 $CLAUDE_DIR"
mkdir -p "$HOOKS_DIR"

# ---------- ① 中文回复指令(写入 CLAUDE.md,sentinel 包裹,幂等) ----------
SENTINEL_BEGIN="<!-- claude-code-zh:begin (勿手动编辑此区块) -->"
SENTINEL_END="<!-- claude-code-zh:end -->"
read -r -d '' ZH_BLOCK <<'EOF' || true
# 语言 / Language
- 默认始终用**简体中文**回复(对话、解释、总结、报错说明)。代码、变量名、commit message、API/库的专有名词保持英文不翻译。
- 写代码注释用中文;commit message 用中文(遵循 conventional 前缀,如 `fix:`/`feat:`)。
- 即使用户用英文提问也用中文回答,除非明确要求英文。子 agent / 工作流面向用户的输出同样用中文。
EOF

touch "$CLAUDE_MD"
if grep -qF "$SENTINEL_BEGIN" "$CLAUDE_MD"; then
  ok "CLAUDE.md 已包含中文指令(跳过)"
else
  { printf '\n%s\n%s\n%s\n' "$SENTINEL_BEGIN" "$ZH_BLOCK" "$SENTINEL_END"; } >> "$CLAUDE_MD"
  ok "已写入中文回复指令到 $CLAUDE_MD"
fi

# ---------- ② tooltip hook ----------
cp "$SCRIPT_DIR/hooks/tool-tips-post.sh" "$HOOKS_DIR/tool-tips-post.sh"
chmod 755 "$HOOKS_DIR/tool-tips-post.sh"
ok "已安装 hook → $HOOKS_DIR/tool-tips-post.sh"

# 备份 settings.json
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.zh.bak"
  ok "已备份 settings.json → settings.json.zh.bak"
fi

# 用 python3 幂等地把 PostToolUse hook 加进 settings.json
HOOK_CMD='~/.claude/hooks/tool-tips-post.sh'
SETTINGS="$SETTINGS" HOOK_CMD="$HOOK_CMD" python3 - <<'PY'
import json, os, sys
path = os.environ["SETTINGS"]
cmd  = os.environ["HOOK_CMD"]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        txt = f.read().strip()
    data = json.loads(txt) if txt else {}
hooks = data.setdefault("hooks", {})
post = hooks.setdefault("PostToolUse", [])
# 是否已安装
exists = any(
    any(h.get("command") == cmd for h in entry.get("hooks", []))
    for entry in post
)
if exists:
    print("PostToolUse hook 已存在(跳过)")
else:
    post.insert(0, {
        "matcher": "",
        "hooks": [{"type": "command", "command": cmd, "timeout": 5}],
    })
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("已把 tooltip hook 写入 settings.json")
PY

# ---------- ③ tooltip 开关命令 + shell 别名 ----------
mkdir -p "$CLAUDE_DIR/bin"
cp "$SCRIPT_DIR/bin/tooltip.sh" "$CLAUDE_DIR/bin/tooltip"
chmod 755 "$CLAUDE_DIR/bin/tooltip"
ok "已安装开关命令 → $CLAUDE_DIR/bin/tooltip"

# 给 zsh / bash 加别名(幂等 + sentinel 可逆)
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -e "$RC" ] || continue
  if grep -qF "claude-code-zh:tooltip" "$RC"; then
    continue
  fi
  {
    echo ""
    echo "# claude-code-zh:tooltip (勿手动编辑此行) — 删除本行及下一行即可移除"
    echo "alias tooltip='bash ~/.claude/bin/tooltip'"
  } >> "$RC"
  ok "已加别名 tooltip → $RC"
done

echo
ok "安装完成!"
warn "重启 Claude Code 后命令 tooltip 才会生效。中文回复指令下个 session 全局生效。"
echo "开关 tooltip:新开终端后敲  tooltip on | off | status  (不带参数=切换)"
echo "卸载:bash $SCRIPT_DIR/uninstall.sh"
