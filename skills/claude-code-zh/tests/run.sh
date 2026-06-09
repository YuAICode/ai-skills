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

echo "== statusline.sh 输出 =="
SL="$DIR/../bin/statusline.sh"
out_sl="$(printf '%s' '{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"/tmp/foo/ai-skills"}}' | bash "$SL")"
ok "statusline 出模型名"      "printf '%s' \"\$out_sl\" | grep -q 'Opus 4.8'"
ok "statusline 出目录 basename" "printf '%s' \"\$out_sl\" | grep -q 'ai-skills'"
ok "statusline 含装饰 🌸"      "printf '%s' \"\$out_sl\" | grep -q '🌸'"
out_sl2="$(printf '%s' '{"workspace":{"current_dir":"/tmp/bar"}}' | bash "$SL")"
ok "缺 model 仍出目录"         "printf '%s' \"\$out_sl2\" | grep -q 'bar'"
out_sl3="$(printf '%s' '{}' | bash "$SL"; echo "rc=$?")"
ok "空 JSON 不报错(rc=0)"     "printf '%s' \"\$out_sl3\" | grep -q 'rc=0'"

echo "== statusline git 分支段 =="
REPO="$TMP/repo"; mkdir -p "$REPO"
( cd "$REPO" && git init -q && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
sl_git="$(printf '%s' "{\"model\":{\"display_name\":\"X\"},\"workspace\":{\"current_dir\":\"$REPO\"}}" | bash "$SL")"
ok "statusline 出 git 分支"    "printf '%s' \"\$sl_git\" | grep -qE 'main|master'"

echo "== ccstatus 开关(临时 CLAUDE_DIR)=="
CC="$DIR/../bin/ccstatus.sh"
mkdir -p "$TMP/bin"
cp "$DIR/../bin/statusline.sh" "$TMP/bin/statusline.sh"
# 预置「别人的」statusLine
echo '{"statusLine":{"type":"command","command":"/other/sl.sh","padding":1}}' > "$TMP/settings.json"
CLAUDE_DIR="$TMP" bash "$CC" on >/dev/null 2>&1
ok "on 后指向我们的脚本"   "python3 -c \"import json;print(json.load(open('$TMP/settings.json'))['statusLine']['command'])\" | grep -q 'statusline.sh'"
ok "on 退避了原 statusLine" "[ -f '$TMP/ccstatus.prev.json' ]"
ok "on 后 settings 合法 JSON" "python3 -c \"import json;json.load(open('$TMP/settings.json'))\""
CLAUDE_DIR="$TMP" bash "$CC" off >/dev/null 2>&1
ok "off 还原原 statusLine"  "python3 -c \"import json;print(json.load(open('$TMP/settings.json'))['statusLine']['command'])\" | grep -q '/other/sl.sh'"
ok "off 后 prev 文件已删"   "[ ! -f '$TMP/ccstatus.prev.json' ]"
# 无原 statusLine:on→off 应干净删键
echo '{}' > "$TMP/settings.json"
CLAUDE_DIR="$TMP" bash "$CC" on  >/dev/null 2>&1
CLAUDE_DIR="$TMP" bash "$CC" off >/dev/null 2>&1
ok "无原值时 off 干净删 statusLine 键" "python3 -c \"import json,sys;sys.exit(0 if 'statusLine' not in json.load(open('$TMP/settings.json')) else 1)\""
# 双重 on:第三方又改了 statusLine 后再 on,不应冲掉最初的原始备份
echo '{"statusLine":{"type":"command","command":"/orig/sl.sh","padding":3}}' > "$TMP/settings.json"
rm -f "$TMP/ccstatus.prev.json"
CLAUDE_DIR="$TMP" bash "$CC" on >/dev/null 2>&1
echo '{"statusLine":{"type":"command","command":"/3rd/foo.sh"}}' > "$TMP/settings.json"
CLAUDE_DIR="$TMP" bash "$CC" on >/dev/null 2>&1
ok "双重 on 保留最初备份" "python3 -c \"import json;print(json.load(open('$TMP/ccstatus.prev.json'))['command'])\" | grep -q '/orig/sl.sh'"

echo "== install / uninstall 往返(临时 HOME+CLAUDE_DIR)=="
SKILL_DIR="$(cd "$DIR/.." && pwd)"
IT="$TMP/inst"; mkdir -p "$IT/.claude"
echo '{}' > "$IT/.claude/settings.json"
touch "$IT/.zshrc"
HOME="$IT" CLAUDE_DIR="$IT/.claude" bash "$SKILL_DIR/install.sh" >/dev/null 2>&1
ok "install 复制了 statusline.sh" "[ -x '$IT/.claude/bin/statusline.sh' ]"
ok "install 复制了 ccstatus"      "[ -x '$IT/.claude/bin/ccstatus' ]"
ok "install 加了 ccstatus 别名"   "grep -q 'claude-code-zh:ccstatus' '$IT/.zshrc'"
ok "install 默认不写 statusLine"  "python3 -c \"import json,sys;sys.exit(0 if 'statusLine' not in json.load(open('$IT/.claude/settings.json')) else 1)\""
HOME="$IT" CLAUDE_DIR="$IT/.claude" bash "$SKILL_DIR/uninstall.sh" >/dev/null 2>&1
ok "uninstall 删了 statusline.sh" "[ ! -e '$IT/.claude/bin/statusline.sh' ]"
ok "uninstall 删了 ccstatus"      "[ ! -e '$IT/.claude/bin/ccstatus' ]"
ok "uninstall 移除了 ccstatus 别名" "! grep -q 'claude-code-zh:ccstatus' '$IT/.zshrc'"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
