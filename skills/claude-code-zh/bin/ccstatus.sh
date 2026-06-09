#!/usr/bin/env bash
# ccstatus — 一键开关 claude-code-zh 中文状态栏
# 用法:
#   ccstatus            切换(开↔关)
#   ccstatus on         开启(备份现有 statusLine 后写入我们的)
#   ccstatus off        关闭(还原备份的 statusLine,无备份则删键)
#   ccstatus status     查看当前状态
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
PREV="$CLAUDE_DIR/ccstatus.prev.json"
OUR_CMD='~/.claude/bin/statusline.sh'
SL_FILE="$CLAUDE_DIR/bin/statusline.sh"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
command -v python3 >/dev/null 2>&1 || { echo "需要 python3"; exit 1; }
[ -f "$SETTINGS" ] || { echo "找不到 $SETTINGS"; exit 1; }

is_on() {
  SETTINGS="$SETTINGS" OUR_CMD="$OUR_CMD" python3 - <<'PY'
import json, os, sys
d = json.load(open(os.environ["SETTINGS"], encoding="utf-8"))
sl = d.get("statusLine") or {}
sys.exit(0 if sl.get("command") == os.environ["OUR_CMD"] else 1)
PY
}

enable() {
  [ -f "$SL_FILE" ] || { printf "${RED}状态栏脚本不存在:%s${NC}\n" "$SL_FILE"; exit 1; }
  SETTINGS="$SETTINGS" OUR_CMD="$OUR_CMD" PREV="$PREV" python3 - <<'PY'
import json, os
p = os.environ["SETTINGS"]; cmd = os.environ["OUR_CMD"]; prev = os.environ["PREV"]
d = json.load(open(p, encoding="utf-8"))
sl = d.get("statusLine")
# 已有别人的 statusLine → 先退避
if isinstance(sl, dict) and sl.get("command") != cmd:
    json.dump(sl, open(prev, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
d["statusLine"] = {"type": "command", "command": cmd, "padding": 0}
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2); open(p, "a").write("\n")
PY
  printf "${GREEN}✅ 中文状态栏已开启${NC}（重启 Claude Code 生效）\n"
}

disable() {
  SETTINGS="$SETTINGS" OUR_CMD="$OUR_CMD" PREV="$PREV" python3 - <<'PY'
import json, os
p = os.environ["SETTINGS"]; cmd = os.environ["OUR_CMD"]; prev = os.environ["PREV"]
d = json.load(open(p, encoding="utf-8"))
sl = d.get("statusLine")
# 只动我们自己的
if isinstance(sl, dict) and sl.get("command") == cmd:
    if os.path.exists(prev):
        d["statusLine"] = json.load(open(prev, encoding="utf-8"))
        os.remove(prev)
    else:
        del d["statusLine"]
    json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2); open(p, "a").write("\n")
PY
  printf "${YELLOW}🔕 中文状态栏已关闭${NC}（重启 Claude Code 生效）\n"
}

case "${1:-toggle}" in
  on)     enable;;
  off)    disable;;
  status) if is_on; then printf "${GREEN}中文状态栏:开启${NC}\n"; else printf "${YELLOW}中文状态栏:关闭${NC}\n"; fi;;
  toggle) if is_on; then disable; else enable; fi;;
  *)      echo "用法: ccstatus [on|off|status]  (不带参数=切换)"; exit 1;;
esac
