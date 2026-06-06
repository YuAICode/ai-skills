#!/usr/bin/env bash
# dockerfile-doctor 测试:造各类 Dockerfile,验证检测规则与退出码。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin/check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# ---- 断言工具 ----

# assert <期望退出码> <测试名> -- <命令...>
assert() {
  local want="$1" name="$2"; shift 2
  local got=0
  "$@" >/dev/null 2>&1 || got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 exit %s,实际 exit %s)${NC}\n" "$name" "$want" "$got"; fail=$((fail+1))
  fi
}

# assert_output_contains <测试名> <关键字> <命令...>
assert_output_contains() {
  local name="$1" needle="$2"; shift 2
  local out got=0
  out="$("$@" 2>&1)" || got=$?
  if printf '%s' "$out" | grep -qi "$needle"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (输出中未找到 '%s')${NC}\n" "$name" "$needle"; fail=$((fail+1))
  fi
}

# assert_output_not_contains <测试名> <关键字> <命令...>
assert_output_not_contains() {
  local name="$1" needle="$2"; shift 2
  local out got=0
  out="$("$@" 2>&1)" || got=$?
  if ! printf '%s' "$out" | grep -qi "$needle"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (输出中不应含 '%s')${NC}\n" "$name" "$needle"; fail=$((fail+1))
  fi
}

# ============================================================
# 场景一:反例 Dockerfile — :latest + ADD + ENV密钥
# ============================================================
echo "== 场景一:反例 Dockerfile (:latest / ADD / ENV密钥) =="
D1="$TMP/bad1"
mkdir -p "$D1"
cat > "$D1/Dockerfile" <<'EOF'
FROM node:latest
WORKDIR /app
ADD package.json /app/
ADD . /app/
RUN npm install
ENV PASSWORD=supersecret123
CMD ["node", "index.js"]
EOF
# 没有 .dockerignore

assert 2 ":latest Dockerfile → exit 2" \
  bash "$BIN" "$D1/Dockerfile"

assert_output_contains ":latest 被检测到" "latest" \
  bash "$BIN" "$D1/Dockerfile"

assert_output_contains "ADD 本地文件被检测到" "ADD" \
  bash "$BIN" "$D1/Dockerfile"

assert_output_contains "ENV PASSWORD 被检测到" "密钥" \
  bash "$BIN" "$D1/Dockerfile"

assert_output_contains "无非 root 用户被检测到" "root" \
  bash "$BIN" "$D1/Dockerfile"

assert_output_contains ".dockerignore 缺失被检测到" "dockerignore" \
  bash "$BIN" "$D1/Dockerfile"

# ============================================================
# 场景二:反例 — 无 tag + COPY . . 在 npm install 之前
# ============================================================
echo ""
echo "== 场景二:无 tag + COPY . . 在依赖安装前 =="
D2="$TMP/bad2"
mkdir -p "$D2"
cat > "$D2/Dockerfile" <<'EOF'
FROM python
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
USER nobody
CMD ["python", "app.py"]
EOF
touch "$D2/.dockerignore"

assert 2 "无 tag + COPY. 在前 → exit 2" \
  bash "$BIN" "$D2/Dockerfile"

assert_output_contains "无 tag 被检测到" "tag" \
  bash "$BIN" "$D2/Dockerfile"

assert_output_contains "COPY . . 缓存问题被检测到" "缓存" \
  bash "$BIN" "$D2/Dockerfile"

# ============================================================
# 场景三:反例 — apt-get 未清理 + 未加 --no-install-recommends
# ============================================================
echo ""
echo "== 场景三:apt-get 未清理缓存 =="
D3="$TMP/bad3"
mkdir -p "$D3"
cat > "$D3/Dockerfile" <<'EOF'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl wget
USER nobody
CMD ["bash"]
EOF
touch "$D3/.dockerignore"

assert 2 "apt 未清理 → exit 2" \
  bash "$BIN" "$D3/Dockerfile"

assert_output_contains "apt 缓存问题被检测到" "apt" \
  bash "$BIN" "$D3/Dockerfile"

assert_output_contains "--no-install-recommends 缺失被检测到" "no-install-recommends" \
  bash "$BIN" "$D3/Dockerfile"

# ============================================================
# 场景四:正例 — 规范 Dockerfile
# ============================================================
echo ""
echo "== 场景四:正例 Dockerfile (应 exit 0) =="
D4="$TMP/good"
mkdir -p "$D4"
cat > "$D4/Dockerfile" <<'EOF'
FROM node:20.11-alpine
WORKDIR /app

# 先拷贝依赖清单,安装依赖(利用构建缓存)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# 再拷贝源码
COPY . .

# 切换为非 root 用户
USER nobody

EXPOSE 3000
CMD ["node", "index.js"]
EOF
touch "$D4/.dockerignore"

assert 0 "规范 Dockerfile → exit 0" \
  bash "$BIN" "$D4/Dockerfile"

assert_output_not_contains "规范 Dockerfile 无 latest 问题" "latest" \
  bash "$BIN" "$D4/Dockerfile"

assert_output_not_contains "规范 Dockerfile 无密钥问题" "密钥" \
  bash "$BIN" "$D4/Dockerfile"

# ============================================================
# 场景五:ENV 密钥各种变体
# ============================================================
echo ""
echo "== 场景五:ENV 密钥变体检测 =="
D5="$TMP/secrets"
mkdir -p "$D5"
cat > "$D5/Dockerfile" <<'EOF'
FROM alpine:3.19
ARG API_KEY=abc123realkey
ENV SECRET_TOKEN=mytoken999
USER nobody
CMD ["sh"]
EOF
touch "$D5/.dockerignore"

assert 2 "ENV/ARG 密钥 → exit 2" \
  bash "$BIN" "$D5/Dockerfile"

assert_output_contains "ARG API_KEY 被检测" "密钥" \
  bash "$BIN" "$D5/Dockerfile"

# ============================================================
# 场景六:scratch 无 tag 不报错
# ============================================================
echo ""
echo "== 场景六:FROM scratch 不报 tag 缺失 =="
D6="$TMP/scratch"
mkdir -p "$D6"
cat > "$D6/Dockerfile" <<'EOF'
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o myapp .

FROM scratch
COPY --from=builder /app/myapp /myapp
USER nobody
ENTRYPOINT ["/myapp"]
EOF
touch "$D6/.dockerignore"

assert 0 "scratch 多阶段构建 → exit 0" \
  bash "$BIN" "$D6/Dockerfile"

# ============================================================
# 场景七:文件不存在 → exit 1
# ============================================================
echo ""
echo "== 场景七:Dockerfile 不存在 → exit 1 =="
assert 1 "不存在的文件 → exit 1" \
  bash "$BIN" "$TMP/nonexistent/Dockerfile"

# ============================================================
# 场景八:ENV 占位符不应触发密钥警告
# ============================================================
echo ""
echo "== 场景八:ENV 占位符不报密钥 =="
D8="$TMP/placeholder"
mkdir -p "$D8"
cat > "$D8/Dockerfile" <<'EOF'
FROM alpine:3.19
ENV PASSWORD=""
USER nobody
CMD ["sh"]
EOF
touch "$D8/.dockerignore"

assert 0 "ENV 空值占位符 → exit 0" \
  bash "$BIN" "$D8/Dockerfile"

# ---- 汇总 ----
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
