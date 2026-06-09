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
    # --porcelain 会把 untracked 文件也算作脏(* 标记),语义更准;
    # 超大 monorepo 上可能略慢,但本 skill 面向的仓库规模可忽略。
    dirty=""
    [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && dirty="*"
    segs+=("🌿 ${branch}${dirty}")
  fi
fi

# 用 │ 拼接(数组长度 guard,bash 3.2 下空数组也安全)
line=""
if [ "${#segs[@]}" -gt 0 ]; then
  for s in "${segs[@]}"; do
    if [ -z "$line" ]; then line="$s"; else line="$line │ $s"; fi
  done
fi

[ -n "$line" ] && printf '🌸 %s\n' "$line"
exit 0
