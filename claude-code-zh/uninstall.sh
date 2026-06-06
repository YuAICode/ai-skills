#!/usr/bin/env bash
# claude-code-zh 卸载脚本:干净移除中文指令 + tooltip hook
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
GREEN='\033[0;32m'; NC='\033[0m'
ok(){ printf "${GREEN}✅ %s${NC}\n" "$1"; }

command -v python3 >/dev/null 2>&1 || { echo "需要 python3"; exit 1; }

# ① 移除 CLAUDE.md 里 sentinel 包裹的区块
if [ -f "$CLAUDE_MD" ]; then
  CLAUDE_MD="$CLAUDE_MD" python3 - <<'PY'
import os, re
p = os.environ["CLAUDE_MD"]
s = open(p, encoding="utf-8").read()
new = re.sub(r"\n*<!-- claude-code-zh:begin.*?claude-code-zh:end -->\n*", "\n", s, flags=re.S)
if new != s:
    open(p, "w", encoding="utf-8").write(new)
    print("已从 CLAUDE.md 移除中文指令区块")
PY
fi

# ② 从 settings.json 移除 hook 条目
if [ -f "$SETTINGS" ]; then
  SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os
p = os.environ["SETTINGS"]
cmd = "~/.claude/hooks/tool-tips-post.sh"
data = json.load(open(p, encoding="utf-8"))
post = data.get("hooks", {}).get("PostToolUse", [])
kept = [e for e in post if not any(h.get("command") == cmd for h in e.get("hooks", []))]
if len(kept) != len(post):
    data["hooks"]["PostToolUse"] = kept
    json.dump(data, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    open(p, "a", encoding="utf-8").write("\n")
    print("已从 settings.json 移除 tooltip hook")
PY
fi

# ③ 删 hook 脚本 + 开关命令
rm -f "$HOOKS_DIR/tool-tips-post.sh" && ok "已删除 hook 脚本"
rm -f "$CLAUDE_DIR/bin/tooltip" && ok "已删除开关命令"

# ④ 移除 shell 别名(sentinel 包裹的两行)
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -e "$RC" ] || continue
  if grep -qF "claude-code-zh:tooltip" "$RC"; then
    RC="$RC" python3 - <<'PY'
import os, re
p = os.environ["RC"]
s = open(p, encoding="utf-8").read()
new = re.sub(r"\n*# claude-code-zh:tooltip.*\nalias tooltip=.*\n", "\n", s)
if new != s:
    open(p, "w", encoding="utf-8").write(new)
    print("已移除别名:", p)
PY
  fi
done
ok "卸载完成。重启 Claude Code / 新开终端生效。"
