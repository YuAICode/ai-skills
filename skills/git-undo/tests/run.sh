#!/usr/bin/env bash
# git-undo 测试：造临时 repo，断言 state.sh 输出含预期内容。
# 离线、纯 bash、无外部依赖。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$DIR/../bin/state.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

ok() {
  local name="$1"
  local expr="$2"
  if eval "$expr"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"
    fail=$((fail+1))
  fi
}

# pipefail 下 cmd|grep 若 cmd 非零会带挂整个脚本——先捕获输出再 grep
capture() {
  bash "$STATE" "$1" 2>&1 || true
}

# ============================================================
# 阶段 1：正常 repo，有几条提交
# ============================================================
REPO="$TMP/repo1"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t.co"
git -C "$REPO" config user.name "tester"

# 造 3 条提交
for msg in "首次提交" "第二次提交" "第三次提交"; do
  git -C "$REPO" -c commit.gpgsign=false commit -q --allow-empty -m "$msg"
done

echo "== 正常 repo（3 条提交）=="
out="$(capture "$REPO")"

ok "退出码为 0（state.sh 正常退出）" "bash \"$STATE\" \"$REPO\" >/dev/null 2>&1"
ok "输出含当前分支标题" "printf '%s' \"\$out\" | grep -q '## 当前分支'"
ok "输出含 reflog 标题" "printf '%s' \"\$out\" | grep -q '## reflog'"
ok "输出含最近提交标题" "printf '%s' \"\$out\" | grep -q '## 最近 5 条提交'"
ok "最近提交含第三次提交" "printf '%s' \"\$out\" | grep -q '第三次提交'"
ok "最近提交含第二次提交" "printf '%s' \"\$out\" | grep -q '第二次提交'"
ok "reflog 段含 commit 记录" "printf '%s' \"\$out\" | grep -q 'commit'"
ok "输出含工作区状态标题" "printf '%s' \"\$out\" | grep -q '## 工作区状态'"
ok "输出含状态摘要标题" "printf '%s' \"\$out\" | grep -q '## 状态摘要'"
ok "干净 repo 无未暂存改动" "printf '%s' \"\$out\" | grep -q '未暂存改动: 无'"
ok "干净 repo 无未提交暂存" "printf '%s' \"\$out\" | grep -q '未提交改动（暂存区）: 无'"
ok "干净 repo 工作区显示干净" "printf '%s' \"\$out\" | grep -q '干净，无未提交/未暂存改动'"
ok "输出含上游分支标题" "printf '%s' \"\$out\" | grep -q '## 上游分支信息'"
ok "无上游时显示无" "printf '%s' \"\$out\" | grep -q '上游分支: 无'"
ok "输出含只读声明" "printf '%s' \"\$out\" | grep -q '只读采集'"

# ============================================================
# 阶段 2：repo 有未暂存改动
# ============================================================
REPO2="$TMP/repo2"
mkdir -p "$REPO2"
git -C "$REPO2" init -q
git -C "$REPO2" config user.email "t@t.co"
git -C "$REPO2" config user.name "tester"
git -C "$REPO2" -c commit.gpgsign=false commit -q --allow-empty -m "init"
# 造一个已跟踪文件并修改
printf "hello\n" > "$REPO2/hello.txt"
git -C "$REPO2" add hello.txt
git -C "$REPO2" -c commit.gpgsign=false commit -q -m "add hello"
# 修改文件（未暂存）
printf "world\n" >> "$REPO2/hello.txt"

echo ""
echo "== repo 有未暂存改动 =="
out2="$(capture "$REPO2")"

ok "有未暂存改动时显示有" "printf '%s' \"\$out2\" | grep -q '未暂存改动: 有'"
ok "暂存区仍为空" "printf '%s' \"\$out2\" | grep -q '未提交改动（暂存区）: 无'"

# ============================================================
# 阶段 3：repo 有未提交改动（暂存区有内容）
# ============================================================
REPO3="$TMP/repo3"
mkdir -p "$REPO3"
git -C "$REPO3" init -q
git -C "$REPO3" config user.email "t@t.co"
git -C "$REPO3" config user.name "tester"
git -C "$REPO3" -c commit.gpgsign=false commit -q --allow-empty -m "init"
printf "staged content\n" > "$REPO3/staged.txt"
git -C "$REPO3" add staged.txt
# 不 commit，暂存区有内容

echo ""
echo "== repo 有暂存区改动（未提交） =="
out3="$(capture "$REPO3")"

ok "暂存区有内容时显示有" "printf '%s' \"\$out3\" | grep -q '未提交改动（暂存区）: 有'"

# ============================================================
# 阶段 4：非 git 目录（反例）
# ============================================================
NOTGIT="$TMP/notgit"
mkdir -p "$NOTGIT"

echo ""
echo "== 非 git 目录（反例）=="
ok "非 git 目录退出码非零" "! bash \"$STATE\" \"$NOTGIT\" >/dev/null 2>&1"
err_out="$(bash "$STATE" "$NOTGIT" 2>&1 || true)"
ok "非 git 目录输出错误提示" "printf '%s' \"\$err_out\" | grep -q '错误'"

# ============================================================
# 阶段 5：分支名正确输出
# ============================================================
echo ""
echo "== 分支名检测 =="
REPO5="$TMP/repo5"
mkdir -p "$REPO5"
git -C "$REPO5" init -q -b feature-xyz 2>/dev/null || git -C "$REPO5" init -q
git -C "$REPO5" config user.email "t@t.co"
git -C "$REPO5" config user.name "tester"
git -C "$REPO5" -c commit.gpgsign=false commit -q --allow-empty -m "init"
# 若 init 不支持 -b，手动切分支
git -C "$REPO5" checkout -b feature-xyz -q 2>/dev/null || true
out5="$(capture "$REPO5")"
ok "输出含分支名 feature-xyz" "printf '%s' \"\$out5\" | grep -q 'feature-xyz'"

# ============================================================
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
