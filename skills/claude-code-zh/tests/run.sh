#!/usr/bin/env bash
# claude-code-zh 测试:验证 tooltip hook 输出 + tooltip 开关命令(临时 CLAUDE_DIR,不碰真实配置)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$DIR/../hooks/tool-tips-post.sh"
TOGGLE="$DIR/../bin/tooltip.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ if eval "$2"; then printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); else printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); fi; }

echo "== tool-tips-post.sh 输出 =="
out_bash="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | bash "$HOOK")"
ok "Bash 命令出中文提示"   "printf '%s' \"\$out_bash\" | grep -q '上传到远程仓库'"
ok "输出是合法 systemMessage JSON" "printf '%s' \"\$out_bash\" | grep -q '\"systemMessage\"'"
out_read="$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"/x/y/app.py"}}' | bash "$HOOK")"
ok "Read 出文件名提示"     "printf '%s' \"\$out_read\" | grep -q 'app.py'"
out_empty="$(printf '%s' '{}' | bash "$HOOK")"
ok "无 tool_name 时不输出" "[ -z \"\$out_empty\" ]"

echo "== tooltip 开关命令(临时 CLAUDE_DIR)=="
mkdir -p "$TMP/hooks"
cp "$DIR/../hooks/tool-tips-post.sh" "$TMP/hooks/tool-tips-post.sh"
echo '{"hooks":{"PostToolUse":[{"matcher":"","hooks":[{"type":"command","command":"~/.claude/hooks/tool-tips-post.sh","timeout":5}]}]}}' > "$TMP/settings.json"
ok "status 报开启"  "CLAUDE_DIR='$TMP' bash '$TOGGLE' status 2>&1 | grep -q '开启'"
ok "off 能关"       "CLAUDE_DIR='$TMP' bash '$TOGGLE' off >/dev/null 2>&1; CLAUDE_DIR='$TMP' bash '$TOGGLE' status 2>&1 | grep -q '关闭'"
ok "off 后 settings 仍合法 JSON" "python3 -c \"import json;json.load(open('$TMP/settings.json'))\""
ok "on 能开回来"    "CLAUDE_DIR='$TMP' bash '$TOGGLE' on >/dev/null 2>&1; CLAUDE_DIR='$TMP' bash '$TOGGLE' status 2>&1 | grep -q '开启'"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
