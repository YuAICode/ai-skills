#!/usr/bin/env bash
# tooltip — 一键开关 claude-code-zh 命令中文提示
# 用法:
#   tooltip            切换(开↔关)
#   tooltip on         开启
#   tooltip off        关闭
#   tooltip status     查看当前状态
# 关闭只是从 settings.json 摘掉 hook 条目,不删脚本,随时可再开。
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD='~/.claude/hooks/tool-tips-post.sh'
HOOK_FILE="$CLAUDE_DIR/hooks/tool-tips-post.sh"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

command -v python3 >/dev/null 2>&1 || { echo "需要 python3"; exit 1; }
[ -f "$SETTINGS" ] || { echo "找不到 $SETTINGS"; exit 1; }

is_on() {
  SETTINGS="$SETTINGS" HOOK_CMD="$HOOK_CMD" python3 - <<'PY'
import json, os, sys
d = json.load(open(os.environ["SETTINGS"], encoding="utf-8"))
cmd = os.environ["HOOK_CMD"]
post = d.get("hooks", {}).get("PostToolUse", [])
on = any(h.get("command") == cmd for e in post for h in e.get("hooks", []))
sys.exit(0 if on else 1)
PY
}

enable() {
  [ -f "$HOOK_FILE" ] || { printf "${RED}hook 脚本不存在:%s${NC}\n" "$HOOK_FILE"; exit 1; }
  SETTINGS="$SETTINGS" HOOK_CMD="$HOOK_CMD" python3 - <<'PY'
import json, os
p = os.environ["SETTINGS"]; cmd = os.environ["HOOK_CMD"]
d = json.load(open(p, encoding="utf-8"))
post = d.setdefault("hooks", {}).setdefault("PostToolUse", [])
if not any(h.get("command") == cmd for e in post for h in e.get("hooks", [])):
    post.insert(0, {"matcher": "", "hooks": [{"type": "command", "command": cmd, "timeout": 5}]})
    json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2); open(p, "a").write("\n")
PY
  printf "${GREEN}✅ tooltip 已开启${NC}（重启 Claude Code 生效）\n"
}

disable() {
  SETTINGS="$SETTINGS" HOOK_CMD="$HOOK_CMD" python3 - <<'PY'
import json, os
p = os.environ["SETTINGS"]; cmd = os.environ["HOOK_CMD"]
d = json.load(open(p, encoding="utf-8"))
post = d.get("hooks", {}).get("PostToolUse", [])
kept = [e for e in post if not any(h.get("command") == cmd for h in e.get("hooks", []))]
if "hooks" in d and "PostToolUse" in d["hooks"]:
    d["hooks"]["PostToolUse"] = kept
    json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2); open(p, "a").write("\n")
PY
  printf "${YELLOW}🔕 tooltip 已关闭${NC}（重启 Claude Code 生效）\n"
}

case "${1:-toggle}" in
  on)     enable;;
  off)    disable;;
  status) if is_on; then printf "${GREEN}tooltip:开启${NC}\n"; else printf "${YELLOW}tooltip:关闭${NC}\n"; fi;;
  toggle) if is_on; then disable; else enable; fi;;
  *)      echo "用法: tooltip [on|off|status]  (不带参数=切换)"; exit 1;;
esac
