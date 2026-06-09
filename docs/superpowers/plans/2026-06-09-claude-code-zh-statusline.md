# claude-code-zh 中文 statusline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 `skills/claude-code-zh` 增加第三项功能——自前轻量中文状态栏(statusline),零 npm、可逆、opt-in。

**Architecture:** 一只极小 bash 脚本 `statusline.sh` 作为 Claude Code 的 `statusLine` 命令:从 stdin 读会话 JSON(python3 解析)取模型名+目录,再调 `git` 取分支,拼成一行中文输出。另配 `ccstatus.sh` 开关命令(仿现有 `tooltip.sh`),用 python3 安全读写 `settings.json` 并退避/还原被覆盖的原 statusLine。install/uninstall 复制脚本+加可逆 alias,但默认不写 statusLine(opt-in)。

**Tech Stack:** bash(兼容 3.2)+ python3(解析/改 JSON)+ git(可选增强);离线 `tests/run.sh` 断言框架。

**约定:** 工作目录 `~/work_study/ai-skills/skills/claude-code-zh`。git 分支图标用 `🌿`(普通 emoji,避免 Nerd Font 依赖;spec 示例里的 powerline glyph 需要特殊字体,故改用 emoji)。所有 commit message 用中文 conventional 前缀。

---

### Task 1: `statusline.sh` —— 中文状态栏命令本体

**Files:**
- Create: `skills/claude-code-zh/bin/statusline.sh`
- Test: `skills/claude-code-zh/tests/run.sh`(在结尾汇总行之前追加用例)

- [ ] **Step 1: 先写失败测试**

打开 `tests/run.sh`,在末尾这段之前:

```bash
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
```

插入以下测试块:

```bash
echo "== statusline.sh 输出 =="
SL="$DIR/../bin/statusline.sh"
out_sl="$(printf '%s' '{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"/tmp/foo/ai-skills"}}' | bash "$SL")"
ok "statusline 出模型名"      "printf '%s' \"\$out_sl\" | grep -q 'Opus 4.8'"
ok "statusline 出目录 basename" "printf '%s' \"\$out_sl\" | grep -q 'ai-skills'"
ok "statusline 含装饰 🌸"      "printf '%s' \"\$out_sl\" | grep -q '🌸'"
out_sl2="$(printf '%s' '{"workspace":{"current_dir":"/tmp/bar"}}' | bash "$SL")"
ok "缺 model 仍出目录"         "printf '%s' \"\$out_sl2\" | grep -q 'bar'"
out_sl3="$(printf '%s' '{}' | bash "$SL"; echo \"rc=\$?\")"
ok "空 JSON 不报错(rc=0)"     "printf '%s' \"\$out_sl3\" | grep -q 'rc=0'"

echo "== statusline git 分支段 =="
REPO="$TMP/repo"; mkdir -p "$REPO"
( cd "$REPO" && git init -q && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )
sl_git="$(printf '%s' "{\"model\":{\"display_name\":\"X\"},\"workspace\":{\"current_dir\":\"$REPO\"}}" | bash "$SL")"
ok "statusline 出 git 分支"    "printf '%s' \"\$sl_git\" | grep -qE 'main|master'"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd skills/claude-code-zh && bash tests/run.sh`
Expected: 新增的 statusline 用例 FAIL(脚本 `bin/statusline.sh` 还不存在,`bash "$SL"` 报 No such file,断言不通过)。

- [ ] **Step 3: 创建 `bin/statusline.sh`**

```bash
#!/usr/bin/env bash
# statusline.sh — claude-code-zh 中文状态栏
# Claude Code statusLine 命令:从 stdin 读会话 JSON,打印一行中文状态。
# 只读取 + 调 git,不写文件、不联网。任何失败都降级,结尾 exit 0。
# License: MIT

raw="$(cat 2>/dev/null)"

# 用 python3 解析 JSON,两行输出:第一行模型名、第二行目录;无 python3 则空
parse() {
  command -v python3 >/dev/null 2>&1 || { printf '\n\n'; return; }
  printf '%s' "$raw" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(); print(); sys.exit(0)
m = d.get("model") or {}
ws = d.get("workspace") or {}
print(m.get("display_name") or m.get("id") or "")
print(ws.get("current_dir") or d.get("cwd") or "")
'
}

info="$(parse)"
model="$(printf '%s' "$info" | sed -n '1p')"
cwd="$(printf '%s' "$info" | sed -n '2p')"

# 收集存在的段(bash 数组,兼容 3.2;不开 set -u,保证不因空展开报错)
segs=()
[ -n "$model" ] && segs+=("🤖 $model")
[ -n "$cwd" ] && segs+=("📁 ${cwd##*/}")

# git 分支段(可选增强):非 git 仓库 / 无 git 命令时整段跳过
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ -n "$branch" ]; then
    dirty=""
    [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && dirty="*"
    segs+=("🌿 ${branch}${dirty}")
  fi
fi

# 用 │ 拼接
line=""
for s in "${segs[@]:-}"; do
  [ -z "$s" ] && continue
  if [ -z "$line" ]; then line="$s"; else line="$line │ $s"; fi
done

[ -n "$line" ] && printf '🌸 %s\n' "$line"
exit 0
```

然后 `chmod 755 bin/statusline.sh`。

- [ ] **Step 4: 跑测试确认通过**

Run: `cd skills/claude-code-zh && bash tests/run.sh`
Expected: 全部 PASS(含新增 statusline / git 分支用例),末行 `0 失败`。

- [ ] **Step 5: 提交**

```bash
cd ~/work_study/ai-skills
git add skills/claude-code-zh/bin/statusline.sh skills/claude-code-zh/tests/run.sh
git commit -m "feat(claude-code-zh): 新增中文状态栏脚本 statusline.sh"
```

---

### Task 2: `ccstatus.sh` —— 状态栏开关命令

**Files:**
- Create: `skills/claude-code-zh/bin/ccstatus.sh`
- Test: `skills/claude-code-zh/tests/run.sh`(继续在汇总行之前追加)

- [ ] **Step 1: 先写失败测试**

在 Task 1 插入的测试块之后、汇总行之前,追加:

```bash
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
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd skills/claude-code-zh && bash tests/run.sh`
Expected: ccstatus 用例 FAIL(`bin/ccstatus.sh` 不存在)。

- [ ] **Step 3: 创建 `bin/ccstatus.sh`**

```bash
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
```

然后 `chmod 755 bin/ccstatus.sh`。

- [ ] **Step 4: 跑测试确认通过**

Run: `cd skills/claude-code-zh && bash tests/run.sh`
Expected: 全部 PASS,末行 `0 失败`。

- [ ] **Step 5: 提交**

```bash
cd ~/work_study/ai-skills
git add skills/claude-code-zh/bin/ccstatus.sh skills/claude-code-zh/tests/run.sh
git commit -m "feat(claude-code-zh): 新增状态栏开关命令 ccstatus"
```

---

### Task 3: 接入 install.sh / uninstall.sh(可逆 + opt-in)

**Files:**
- Modify: `skills/claude-code-zh/install.sh`(在「③ tooltip 开关命令」别名 for 循环之后、末尾 `echo` 之前插入)
- Modify: `skills/claude-code-zh/uninstall.sh`(在「③ 删脚本」之后插入还原+删除;在 rc 别名移除循环里补 ccstatus)
- Test: `skills/claude-code-zh/tests/run.sh`(追加 install/uninstall 往返用例)

- [ ] **Step 1: 先写失败测试**

在汇总行之前追加(用临时 HOME + CLAUDE_DIR,完全隔离真实配置):

```bash
echo "== install / uninstall 往返(临时 HOME+CLAUDE_DIR)=="
SKILL_DIR="$(cd "$DIR/.." && pwd)"
IT="$TMP/inst"; mkdir -p "$IT/.claude"
echo '{}' > "$IT/.claude/settings.json"
HOME="$IT" CLAUDE_DIR="$IT/.claude" bash "$SKILL_DIR/install.sh" >/dev/null 2>&1
ok "install 复制了 statusline.sh" "[ -x '$IT/.claude/bin/statusline.sh' ]"
ok "install 复制了 ccstatus"      "[ -x '$IT/.claude/bin/ccstatus' ]"
ok "install 加了 ccstatus 别名"   "grep -q 'claude-code-zh:ccstatus' '$IT/.zshrc'"
ok "install 默认不写 statusLine"  "python3 -c \"import json,sys;sys.exit(0 if 'statusLine' not in json.load(open('$IT/.claude/settings.json')) else 1)\""
HOME="$IT" CLAUDE_DIR="$IT/.claude" bash "$SKILL_DIR/uninstall.sh" >/dev/null 2>&1
ok "uninstall 删了 statusline.sh" "[ ! -e '$IT/.claude/bin/statusline.sh' ]"
ok "uninstall 删了 ccstatus"      "[ ! -e '$IT/.claude/bin/ccstatus' ]"
ok "uninstall 移除了 ccstatus 别名" "! grep -q 'claude-code-zh:ccstatus' '$IT/.zshrc'"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd skills/claude-code-zh && bash tests/run.sh`
Expected: install/uninstall 往返用例 FAIL(install.sh 还没复制 statusline/ccstatus,断言 `[ -x ... ]` 不成立)。

- [ ] **Step 3a: 改 install.sh**

在 `install.sh` 中「③ tooltip 开关命令」那段的别名 for 循环结束之后(即 `done` 之后)、文件末尾 `echo`/`ok "安装完成!"` 之前,插入:

```bash
# ---------- ④ 中文状态栏脚本 + ccstatus 开关命令(默认不启用,需 ccstatus on) ----------
cp "$SCRIPT_DIR/bin/statusline.sh" "$CLAUDE_DIR/bin/statusline.sh"
chmod 755 "$CLAUDE_DIR/bin/statusline.sh"
ok "已安装状态栏脚本 → $CLAUDE_DIR/bin/statusline.sh"
cp "$SCRIPT_DIR/bin/ccstatus.sh" "$CLAUDE_DIR/bin/ccstatus"
chmod 755 "$CLAUDE_DIR/bin/ccstatus"
ok "已安装开关命令 → $CLAUDE_DIR/bin/ccstatus"

for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -e "$RC" ] || continue
  if grep -qF "claude-code-zh:ccstatus" "$RC"; then
    continue
  fi
  {
    echo ""
    echo "# claude-code-zh:ccstatus (勿手动编辑此行) — 删除本行及下一行即可移除"
    echo "alias ccstatus='bash ~/.claude/bin/ccstatus'"
  } >> "$RC"
  ok "已加别名 ccstatus → $RC"
done
```

并把文件末尾的提示行(`echo "开关 tooltip:..."` 那块附近)补一行:

```bash
echo "开启中文状态栏:新开终端后敲  ccstatus on  (默认未启用;off 关闭、status 查状态)"
```

- [ ] **Step 3b: 改 uninstall.sh**

在 uninstall.sh「③ 删 hook 脚本 + 开关命令」那段(`rm -f "$CLAUDE_DIR/bin/tooltip" ...`)之后,插入还原+删除块:

```bash
# ③' 还原/移除中文状态栏(只动我们自己的 statusLine)
if [ -f "$SETTINGS" ]; then
  SETTINGS="$SETTINGS" PREV="$CLAUDE_DIR/ccstatus.prev.json" python3 - <<'PY'
import json, os
p = os.environ["SETTINGS"]; prev = os.environ["PREV"]
cmd = "~/.claude/bin/statusline.sh"
d = json.load(open(p, encoding="utf-8"))
sl = d.get("statusLine")
if isinstance(sl, dict) and sl.get("command") == cmd:
    if os.path.exists(prev):
        d["statusLine"] = json.load(open(prev, encoding="utf-8")); os.remove(prev)
    else:
        del d["statusLine"]
    json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    open(p, "a", encoding="utf-8").write("\n")
    print("已还原/移除中文状态栏")
PY
fi
rm -f "$CLAUDE_DIR/bin/statusline.sh" && ok "已删除状态栏脚本"
rm -f "$CLAUDE_DIR/bin/ccstatus" && ok "已删除 ccstatus 命令"
rm -f "$CLAUDE_DIR/ccstatus.prev.json" 2>/dev/null || true
```

并在「④ 移除 shell 别名」的 for 循环里,补一段移除 ccstatus 别名(放在现有 tooltip 移除之后、`done` 之前):

```bash
  if grep -qF "claude-code-zh:ccstatus" "$RC"; then
    RC="$RC" python3 - <<'PY'
import os, re
p = os.environ["RC"]
s = open(p, encoding="utf-8").read()
new = re.sub(r"\n*# claude-code-zh:ccstatus.*\nalias ccstatus=.*\n", "\n", s)
if new != s:
    open(p, "w", encoding="utf-8").write(new)
    print("已移除别名:", p)
PY
  fi
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd skills/claude-code-zh && bash tests/run.sh`
Expected: 全部 PASS,末行 `0 失败`。

- [ ] **Step 5: 提交**

```bash
cd ~/work_study/ai-skills
git add skills/claude-code-zh/install.sh skills/claude-code-zh/uninstall.sh skills/claude-code-zh/tests/run.sh
git commit -m "feat(claude-code-zh): install/uninstall 接入 statusline(opt-in 可逆)"
```

---

### Task 4: 文档更新(SKILL.md + README.md)

**Files:**
- Modify: `skills/claude-code-zh/SKILL.md`
- Modify: `skills/claude-code-zh/README.md`

- [ ] **Step 1: 改 SKILL.md 能力表**

把 SKILL.md 里这一行:

```markdown
| ③ 界面 chrome(菜单/状态栏/`/config`) | ❌ | Claude Code v2.1.113+ 已是编译二进制,无 `cli.js`,字符串替换汉化方案全部失效。别尝试改二进制(会破坏代码签名 + 升级即失效)。 |
```

改为两行:

```markdown
| ③ 中文状态栏(statusline) | ✅ | 自前轻量 bash 脚本,经 `settings.json` 的 `statusLine` 输出「模型名 / 目录 / git 分支」。默认不启用,`ccstatus on` 开启。 |
| ④ 界面 chrome(菜单/`/config` 面板) | ❌ | Claude Code v2.1.113+ 已是编译二进制,无 `cli.js`,字符串替换汉化方案全部失效。别尝试改二进制(会破坏代码签名 + 升级即失效)。 |
```

- [ ] **Step 2: 在 SKILL.md「如何使用」补 ccstatus 段**

在「### 卸载」之前插入:

```markdown
### 中文状态栏(可选)
```bash
ccstatus on       # 开启:底部显示 🌸 🤖 模型 │ 📁 目录 │ 🌿 分支
ccstatus off      # 关闭(还原你原来的 statusLine)
ccstatus status   # 查看当前状态
```
默认不启用;开启会备份你已有的 `statusLine`,关闭时还原。改动 settings.json 后需**重启 Claude Code** 生效。
```

- [ ] **Step 3: 改 README.md 功能表 + 加状态栏小节**

README.md 功能表把 ③ 行替换为(同 SKILL.md 的两行 ③/④),并在「🔘 一键开关 tooltip」小节之后新增:

```markdown
## 🪧 中文状态栏(可选,默认不启用)

底部状态栏显示「模型 / 目录 / git 分支」的中文版,自前轻量 bash,不依赖 npm、不 fork 任何项目:

```
🌸 🤖 Opus 4.8 │ 📁 ai-skills │ 🌿 main*
```

```bash
ccstatus on        # 开启
ccstatus off       # 关闭(还原原有 statusLine)
ccstatus status    # 查看状态
```

> `statusLine` 在 settings.json 里是单一槽位,开启会先**备份**你已有的状态栏配置,关闭时**还原**。改完需**重启 Claude Code** 生效。
```

- [ ] **Step 4: 验证文档与 skill-doctor**

Run: `cd skills && bash skill-doctor/bin/*.sh claude-code-zh 2>/dev/null || bash skill-doctor/bin/skill-doctor.sh ../skills/claude-code-zh`
(若 skill-doctor 入口名不同,先 `ls skill-doctor/bin/` 确认可执行脚本名再跑)
Expected: claude-code-zh 通过(frontmatter / name 匹配 / README 徽章 / 有 bin 必有 tests)。

- [ ] **Step 5: 提交**

```bash
cd ~/work_study/ai-skills
git add skills/claude-code-zh/SKILL.md skills/claude-code-zh/README.md
git commit -m "docs(claude-code-zh): 文档加入中文状态栏(③)说明"
```

---

### Task 5: 全量验证

- [ ] **Step 1: 跑完整测试**

Run: `cd skills/claude-code-zh && bash tests/run.sh`
Expected: 末行 `N 通过 / 0 失败`,退出码 0。

- [ ] **Step 2: skill-doctor 全合集(可选,发布前)**

Run: `cd skills && bash skill-doctor/bin/skill-doctor.sh`(按 skill-doctor 实际用法)
Expected: claude-code-zh 无告警。

- [ ] **Step 3: 真机冒烟(手动,可选)**

在真实环境:`bash install.sh` → `ccstatus on` → 重启 Claude Code,确认底部出现中文三段状态栏;`ccstatus off` 还原;`bash uninstall.sh` 后 `~/.claude/bin/` 无 statusline.sh / ccstatus 残留、settings.json 无我们的 statusLine。

---

## 自查(Self-Review)

**Spec 覆盖:**
- §3 显示内容(模型/目录/分支,不含 token)→ Task 1 statusline.sh ✅
- §4.1 statusline.sh → Task 1 ✅
- §4.2 ccstatus.sh(on 退避 / off 还原 / status)→ Task 2 ✅
- §4.3 install(复制脚本+别名,不写 statusLine)→ Task 3a ✅
- §4.4 uninstall(还原+删除+移别名)→ Task 3b ✅
- §4.5 tests(statusline 输出 / git 段 / ccstatus 往返 / 无原值删键)→ Task 1+2 测试,install 往返 → Task 3 ✅
- §4.6 文档(SKILL/README、③ 行、ccstatus 用法)→ Task 4 ✅
- §6 验收(tests 全绿 / skill-doctor / 真机)→ Task 5 ✅

**占位符扫描:** 无 TBD/TODO;每个代码步骤含完整代码。

**类型/命名一致性:** `OUR_CMD='~/.claude/bin/statusline.sh'` 在 ccstatus.sh(Task 2)与 uninstall.sh(Task 3b)、install 复制路径(Task 3a)三处一致;退避文件统一 `ccstatus.prev.json`;sentinel 统一 `claude-code-zh:ccstatus`;is_on 按 `statusLine.command == OUR_CMD` 判断,与 enable/disable 写入的 command 一致。

**已知风险:** Task 3 的 install 往返测试会调用真实 `install.sh`,它会写入临时 `$IT/.zshrc`、临时 `$IT/.claude/CLAUDE.md`——已用临时 HOME/CLAUDE_DIR 完全隔离,不碰真实配置。git 默认分支名可能是 main 或 master,测试用 `grep -qE 'main|master'` 兼容。
