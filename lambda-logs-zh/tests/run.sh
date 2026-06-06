#!/usr/bin/env bash
# lambda-logs-zh 测试:用 aws stub 验证参数拼装,不依赖真实 AWS。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH="$DIR/../bin/fetch-errors.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ if eval "$2"; then printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); else printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); fi; }

# stub aws:把收到的参数原样打印,方便断言
cat > "$TMP/aws" <<'EOF'
#!/bin/sh
echo "AWS_ARGS: $*"
EOF
chmod +x "$TMP/aws"

echo "== 函数名 → 日志组 =="
out="$(AWS_CLI="$TMP/aws" bash "$FETCH" my-func 6h ap-southeast-1)"
ok "日志组拼成 /aws/lambda/my-func" "printf '%s' \"\$out\" | grep -q 'LOG_GROUP: /aws/lambda/my-func'"
ok "窗口显示 6h"                    "printf '%s' \"\$out\" | grep -q 'WINDOW: 最近 6h'"
ok "调用 filter-log-events"          "printf '%s' \"\$out\" | grep -q 'filter-log-events'"
ok "带上 --region"                  "printf '%s' \"\$out\" | grep -q -- '--region ap-southeast-1'"
ok "带上 --start-time"               "printf '%s' \"\$out\" | grep -q -- '--start-time'"

echo "== --group 直传 =="
out2="$(AWS_CLI="$TMP/aws" bash "$FETCH" --group /aws/lambda/other 24h)"
ok "直传日志组生效"  "printf '%s' \"\$out2\" | grep -q 'LOG_GROUP: /aws/lambda/other'"

echo "== 防御 =="
ok "aws 缺失报错"   "! AWS_CLI=/nonexistent/aws bash '$FETCH' my-func 2>/dev/null"
ok "无参数报错"     "! AWS_CLI='$TMP/aws' bash '$FETCH' 2>/dev/null"

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
