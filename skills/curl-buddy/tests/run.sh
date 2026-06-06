#!/usr/bin/env bash
# curl-buddy 测试:对 bin/parse-curl.sh 喂各类 curl 命令,断言退出码与输出字段。
# 纯离线:所有输入使用 example.com 等占位域名,脚本不联网。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin/parse-curl.sh"

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# assert_exit <期望 exit> "<测试名>" "<curl 命令>"
assert_exit() {
  local want="$1" name="$2" cmd="$3"
  local got
  bash "$BIN" "$cmd" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 exit %s,实际 exit %s)${NC}\n" "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# assert_field <测试名> <字段前缀> <期望子串> "<curl 命令>"
# 检查输出中以 <字段前缀>= 开头的那一行包含 <期望子串>
assert_field() {
  local name="$1" field="$2" expect="$3" cmd="$4"
  local out
  out=$(bash "$BIN" "$cmd" 2>/dev/null)
  local line
  line=$(printf '%s' "$out" | grep "^${field}=")
  if printf '%s' "$line" | grep -qF -- "$expect"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s${NC}\n" "$name"
    printf "     期望 %s= 含: %s\n" "$field" "$expect"
    printf "     实际行: %s\n" "$line"
    fail=$((fail+1))
  fi
}

# assert_no_network — 确认脚本不发网络请求:
# 让 /bin/sh 的 PATH 不含 curl 实体,确认脚本仍能成功解析(纯解析不依赖 curl 二进制)
assert_no_network() {
  local name="$1" cmd="$2"
  local got
  PATH=/usr/bin:/bin bash "$BIN" "$cmd" >/dev/null 2>&1
  got=$?
  if [ "$got" = "0" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"
    pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (exit %s,期望 0)${NC}\n" "$name" "$got"
    fail=$((fail+1))
  fi
}

# ────────────────────────────────────────────────────────────────────────
echo "== 退出码:有效命令 =="

assert_exit 0 "裸 GET — exit 0" \
  'curl https://example.com/api'

assert_exit 0 "-X POST — exit 0" \
  'curl -X POST https://example.com/users -d name=foo'

assert_exit 0 "多个 -H — exit 0" \
  'curl -H "Content-Type: application/json" -H "Authorization: Bearer tok" https://example.com'

assert_exit 0 "-k -L flag — exit 0" \
  'curl -k -L https://example.com/'

assert_exit 0 "-u Basic Auth — exit 0" \
  'curl -u admin:secret https://example.com/admin'

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== 退出码:无效命令 =="

assert_exit 2 "非 curl 开头 — exit 2" \
  'wget https://example.com'

assert_exit 2 "无 URL — exit 2" \
  'curl -X GET'

assert_exit 2 "完全空串 — exit 2" \
  ''

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== METHOD 字段解析 =="

assert_field "-X POST 解析出 METHOD=POST" METHOD POST \
  'curl -X POST https://example.com/users -d foo=bar'

assert_field "-X PUT 解析出 METHOD=PUT" METHOD PUT \
  'curl -X PUT https://example.com/items/1 -d x=1'

assert_field "-X DELETE 解析出 METHOD=DELETE" METHOD DELETE \
  'curl -X DELETE https://example.com/items/1'

assert_field "无 -X 有 -d 默认 METHOD=POST" METHOD POST \
  'curl https://example.com/items -d foo=bar'

assert_field "无 -X 无 -d 默认 METHOD=GET" METHOD GET \
  'curl https://example.com/items'

assert_field "--request PATCH 解析 METHOD" METHOD PATCH \
  'curl --request PATCH https://example.com/items/1 -d x=1'

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== URL 字段解析 =="

assert_field "裸 URL 被识别" URL 'https://example.com/api' \
  'curl https://example.com/api'

assert_field "URL 含路径和查询参数" URL '/search?q=hello' \
  'curl https://example.com/search?q=hello'

assert_field "URL 在 -X 之后" URL 'https://example.com/users' \
  'curl -X POST https://example.com/users -d x=1'

assert_field "URL 在 -H 之后" URL 'https://example.com/me' \
  'curl -H "Authorization: Bearer tok" https://example.com/me'

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== HEADERS 字段解析 =="

assert_field "-H 单个 header 进 HEADERS" HEADERS 'Content-Type: application/json' \
  'curl -H "Content-Type: application/json" https://example.com'

assert_field "-H 多个 header 用 | 分隔" HEADERS 'Authorization: Bearer tok' \
  'curl -H "Authorization: Bearer tok" -H "Content-Type: application/json" https://example.com'

assert_field "第二个 -H 也在 HEADERS 中" HEADERS 'Content-Type: application/json' \
  'curl -H "Authorization: Bearer tok" -H "Content-Type: application/json" https://example.com'

assert_field "-b Cookie 进 HEADERS" HEADERS 'Cookie:' \
  'curl -b "session=abc123" https://example.com/dashboard'

assert_field "-u 认证进 HEADERS" HEADERS 'Authorization: Basic' \
  'curl -u admin:secret https://example.com/admin'

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== DATA 字段解析 =="

assert_field "-d 数据进 DATA" DATA '{"name":"foo"}' \
  "curl -X POST https://example.com/users -d '{\"name\":\"foo\"}'"

assert_field "--data 进 DATA" DATA 'key=value' \
  'curl --data "key=value" https://example.com/form'

assert_field "--data-raw 进 DATA" DATA 'raw body' \
  "curl --data-raw 'raw body' https://example.com/"

assert_field "-F 表单字段进 DATA" DATA 'form:' \
  'curl -F "file=@photo.jpg" https://example.com/upload'

assert_field "无 body 时 DATA 为空" DATA '' \
  'curl https://example.com/items'

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== FLAGS 字段解析 =="

assert_field "-k 进 FLAGS" FLAGS '-k' \
  'curl -k https://example.com/'

assert_field "-L 进 FLAGS" FLAGS '-L' \
  'curl -L https://example.com/'

assert_field "-k -L 均在 FLAGS" FLAGS '-L' \
  'curl -k -L https://example.com/'

assert_field "-s 进 FLAGS" FLAGS '-s' \
  'curl -s https://example.com/'

assert_field "-v 进 FLAGS" FLAGS '-v' \
  'curl -v https://example.com/'

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== 多行续行符 =="

assert_field "多行 -H 解析" HEADERS 'Authorization: Bearer tok' \
  "$(printf 'curl -X POST https://example.com/api \\\n  -H "Authorization: Bearer tok" \\\n  -d '"'"'{}'"'"'')"

assert_field "多行 URL 解析" URL 'https://example.com/api' \
  "$(printf 'curl -X POST https://example.com/api \\\n  -H "Content-Type: application/json"')"

# ────────────────────────────────────────────────────────────────────────
echo ""
echo "== 脚本不执行网络请求(无 curl 二进制也能解析) =="

assert_no_network "限制 PATH 仍可解析 GET" \
  'curl https://example.com/api'

assert_no_network "限制 PATH 仍可解析 POST" \
  'curl -X POST https://example.com/users -d x=1'

# ────────────────────────────────────────────────────────────────────────
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
