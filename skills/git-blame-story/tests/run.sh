#!/usr/bin/env bash
# git-blame-story 测试:临时 repo 造文件、多次提交,验证 collect.sh 输出正确。
# 离线测试,不依赖网络,纯 bash + git。
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$DIR/../bin/collect.sh"

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

fail_test() {
  local name="$1"
  printf "${RED}  ✗ %s${NC}\n" "$name"
  fail=$((fail+1))
}

# ---- 搭建临时 repo ----
cd "$TMP"
git init -q
git config user.email "test@example.com"
git config user.name "测试用户"

# 辅助函数:创建提交(跳过 GPG 签名)
c() {
  local msg="$1"
  git -c commit.gpgsign=false commit -q --allow-empty -m "$msg"
}

# 创建目标文件并做多次提交
echo "version 1" > story.txt
git add story.txt
git -c commit.gpgsign=false commit -q -m "init: 创建 story.txt"

echo "version 2" >> story.txt
git add story.txt
git -c commit.gpgsign=false commit -q -m "feat: 添加第二行内容"

echo "version 3" >> story.txt
git add story.txt
git -c commit.gpgsign=false commit -q -m "fix: 修复格式问题"

echo "version 4" >> story.txt
git add story.txt
git -c commit.gpgsign=false commit -q -m "refactor: 重构文件结构"

echo "version 5" >> story.txt
git add story.txt
git -c commit.gpgsign=false commit -q -m "chore: 更新说明"

# ---- 正例测试:采集 story.txt ----
echo "== 正例:story.txt 历史采集 =="
out="$(bash "$COLLECT" story.txt)"

ok "META 段存在"            "printf '%s' \"\$out\" | grep -q '^META:'"
ok "META 含文件名"          "printf '%s' \"\$out\" | grep -q 'story.txt'"
ok "META 含 total_commits"  "printf '%s' \"\$out\" | grep -q 'total_commits:'"
ok "共有5次提交"            "printf '%s' \"\$out\" | grep -q 'total_commits:.*5'"
ok "COMMITS 段存在"         "printf '%s' \"\$out\" | grep -q '^COMMITS:'"
ok "COMMITS 含 init 提交"   "printf '%s' \"\$out\" | grep -q '创建 story.txt'"
ok "COMMITS 含 fix 提交"    "printf '%s' \"\$out\" | grep -q '修复格式问题'"
ok "COMMITS 含 refactor 提交" "printf '%s' \"\$out\" | grep -q '重构文件结构'"
ok "CONTRIBUTORS 段存在"    "printf '%s' \"\$out\" | grep -q '^CONTRIBUTORS:'"
ok "贡献者含测试用户"        "printf '%s' \"\$out\" | grep -q '测试用户'"
ok "TIMELINE 段存在"         "printf '%s' \"\$out\" | grep -q '^TIMELINE:'"
ok "TIMELINE 含首次提交"     "printf '%s' \"\$out\" | grep -q '首次提交'"
ok "TIMELINE 含最近提交"     "printf '%s' \"\$out\" | grep -q '最近提交'"
ok "首次提交含 init"         "printf '%s' \"\$out\" | grep '首次提交' | grep -q 'init'"
ok "最近提交含 chore"        "printf '%s' \"\$out\" | grep '最近提交' | grep -q 'chore'"
ok "CHURN 段存在"            "printf '%s' \"\$out\" | grep -q '^CHURN'"

# ---- 正例测试:退出码为 0 ----
echo "== 正例:退出码 =="
if bash "$COLLECT" story.txt >/dev/null 2>&1; then
  printf "${GREEN}  ✓ 成功采集,退出码 0${NC}\n"; pass=$((pass+1))
else
  printf "${RED}  ✗ 成功采集但退出码非 0${NC}\n"; fail=$((fail+1))
fi

# ---- 反例测试:不存在的文件 ----
echo "== 反例:不存在的文件 =="
err_out="$(bash "$COLLECT" no_such_file.txt 2>&1 || true)"
if bash "$COLLECT" no_such_file.txt >/dev/null 2>&1; then
  printf "${RED}  ✗ 不存在文件应报错但返回了 0${NC}\n"; fail=$((fail+1))
else
  printf "${GREEN}  ✓ 不存在文件正确退出非0${NC}\n"; pass=$((pass+1))
fi
ok "错误信息含 ERROR"        "printf '%s' \"\$err_out\" | grep -q 'ERROR'"
ok "错误信息含文件名"         "printf '%s' \"\$err_out\" | grep -q 'no_such_file.txt'"

# ---- 反例测试:git 未追踪的文件 ----
echo "== 反例:未追踪文件 =="
echo "untracked content" > untracked_file.txt
# 不 git add,所以 git 不追踪
err_out2="$(bash "$COLLECT" untracked_file.txt 2>&1 || true)"
if bash "$COLLECT" untracked_file.txt >/dev/null 2>&1; then
  printf "${RED}  ✗ 未追踪文件应报错但返回了 0${NC}\n"; fail=$((fail+1))
else
  printf "${GREEN}  ✓ 未追踪文件正确退出非0${NC}\n"; pass=$((pass+1))
fi
ok "未追踪错误信息含 ERROR"   "printf '%s' \"\$err_out2\" | grep -q 'ERROR'"

# ---- 反例测试:缺少参数 ----
echo "== 反例:缺少文件参数 =="
err_out3="$(bash "$COLLECT" 2>&1 || true)"
if bash "$COLLECT" >/dev/null 2>&1; then
  printf "${RED}  ✗ 缺少参数应报错但返回了 0${NC}\n"; fail=$((fail+1))
else
  printf "${GREEN}  ✓ 缺少参数正确退出非0${NC}\n"; pass=$((pass+1))
fi
ok "缺参错误信息含 ERROR"     "printf '%s' \"\$err_out3\" | grep -q 'ERROR'"

# ---- 结果汇总 ----
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
