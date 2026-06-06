#!/usr/bin/env bash
# port-killer 测试:验证端口校验、空闲提示、lsof 缺失报错、实际监听检测(可选)。
# pipefail 环境下先捕获输出再 grep,避免管道破裂误报。
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin/whoport.sh"

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'

# ---------- 断言辅助 ----------
# assert_exit <期望码> <说明> -- <命令...>
assert_exit() {
  local want="$1" name="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 exit %s,实际 exit %s)${NC}\n" "$name" "$want" "$got"; fail=$((fail+1))
  fi
}

# assert_output_contains <期望码> <grep模式> <说明> -- <命令...>
# 先捕获 stdout+stderr,再 grep — 避免 pipefail 下管道破裂误报
assert_output_contains() {
  local want_exit="$1" pattern="$2" name="$3"; shift 4
  local out grep_ok=0 got_exit
  # 用临时文件捕获输出,避免 $() 的 subshell 吃掉 exit code
  local _tmp_out
  _tmp_out="$(mktemp)"
  "$@" >"$_tmp_out" 2>&1; got_exit=$?
  out="$(cat "$_tmp_out")"; rm -f "$_tmp_out"
  printf '%s' "$out" | grep -qE "$pattern" && grep_ok=1 || true

  if [ "$got_exit" = "$want_exit" ] && [ "$grep_ok" = "1" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"; fail=$((fail+1))
    [ "$got_exit" != "$want_exit" ] && printf "     exit 期望 %s,实际 %s\n" "$want_exit" "$got_exit"
    [ "$grep_ok" = "0" ] && printf "     输出未匹配:/%s/\n     输出:%s\n" "$pattern" "$out"
  fi
}

# ---------- 1. 端口格式校验 ----------
echo "== 端口格式校验 =="

assert_exit        1 "非数字端口 'abc' 报错"         -- bash "$BIN" abc
assert_exit        1 "非数字端口 '80x' 报错"         -- bash "$BIN" 80x
assert_exit        1 "端口 0 越界 报错"              -- bash "$BIN" 0
assert_exit        1 "端口 65536 越界 报错"          -- bash "$BIN" 65536
assert_exit        1 "端口 99999 越界 报错"          -- bash "$BIN" 99999
assert_exit        1 "浮点端口 '80.5' 报错"          -- bash "$BIN" 80.5

assert_output_contains 1 "1-65535|1\.\.65535" \
  "越界提示含范围说明"                                 -- bash "$BIN" 65536
assert_output_contains 1 "整数|数字"          \
  "非数字提示含说明"                                   -- bash "$BIN" abc

# ---------- 2. 空闲端口提示(需 lsof) ----------
echo "== 空闲端口提示 =="

LSOF_CMD="${LSOF:-lsof}"
FREE_PORT=59871

if command -v "$LSOF_CMD" >/dev/null 2>&1; then
  for p in 59871 59872 59873 59874 59875; do
    if ! "$LSOF_CMD" -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
      FREE_PORT=$p; break
    fi
  done

  assert_exit 1 "空闲端口 exit 1" \
    -- bash "$BIN" "$FREE_PORT"
  assert_output_contains 1 "没人占用|空闲" \
    "空闲端口有友好提示"                                -- bash "$BIN" "$FREE_PORT"
else
  printf "${YELLOW}  跳过 空闲端口测试(lsof 不存在)${NC}\n"
fi

# ---------- 3. lsof 不存在时优雅报错 ----------
echo "== lsof 缺失报错 =="

assert_exit 1 "lsof 不存在 exit 1" \
  -- env LSOF=/nonexistent/lsof bash "$BIN" 8080
assert_output_contains 1 "lsof|替代|ss|netstat" \
  "lsof 缺失给替代命令提示"                            -- env LSOF=/nonexistent/lsof bash "$BIN" 8080

# ---------- 4. --kill 缺 --yes 时要求确认(用 lsof stub) ----------
echo "== --kill 缺 --yes 要求确认 =="

TMP_STUB="$(mktemp)"
trap 'rm -f "$TMP_STUB"' EXIT
cat > "$TMP_STUB" <<'STUB'
#!/bin/sh
# 模拟 lsof 返回一个假 LISTEN 进程(不依赖真实网络)
echo "COMMAND    PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME"
echo "python3  99999 testuser  6u  IPv4 0x1234      0t0  TCP *:18080 (LISTEN)"
STUB
chmod +x "$TMP_STUB"

assert_exit 1 "--kill 没有 --yes 时 exit 1" \
  -- env LSOF="$TMP_STUB" bash "$BIN" 18080 --kill
assert_output_contains 1 "\-\-yes|确认" \
  "--kill 缺 --yes 提示含确认说明"                     -- env LSOF="$TMP_STUB" bash "$BIN" 18080 --kill

# ---------- 5. 实际监听进程检测(可选,需 python3 + lsof) ----------
echo "== 实际监听进程检测(可选) =="

if command -v "$LSOF_CMD" >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  TEST_PORT=0
  for p in 18765 18766 18767 18768 18769; do
    if ! "$LSOF_CMD" -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
      TEST_PORT=$p; break
    fi
  done

  if [ "$TEST_PORT" -eq 0 ]; then
    printf "${YELLOW}  跳过:找不到空闲测试端口${NC}\n"
  else
    # 启后台 HTTP server
    python3 -m http.server "$TEST_PORT" >/dev/null 2>&1 &
    SERVER_PID=$!

    # 等最多 3 秒进入 LISTEN(先等 1 秒再检查,最多 3 次)
    LISTEN_OK=0
    i=0
    while [ $i -lt 3 ]; do
      sleep 1
      if "$LSOF_CMD" -nP -iTCP:"$TEST_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        LISTEN_OK=1; break
      fi
      i=$((i+1))
    done

    if [ "$LISTEN_OK" -eq 1 ]; then
      assert_exit 0 "实际监听进程 exit 0(找到)" \
        -- bash "$BIN" "$TEST_PORT"
      assert_output_contains 0 "$SERVER_PID" \
        "输出中含测试进程 PID"                          -- bash "$BIN" "$TEST_PORT"
      assert_output_contains 0 "[Pp]ython" \
        "输出中含 python 命令名"                        -- bash "$BIN" "$TEST_PORT"
    else
      printf "${YELLOW}  跳过:python3 server 未在规定时间内进入 LISTEN${NC}\n"
    fi

    # 清理测试进程
    kill "$SERVER_PID" 2>/dev/null || true
  fi
else
  if ! command -v python3 >/dev/null 2>&1; then
    printf "${YELLOW}  跳过:未找到 python3${NC}\n"
  else
    printf "${YELLOW}  跳过:未找到 lsof${NC}\n"
  fi
fi

# ---------- 汇总 ----------
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
