#!/usr/bin/env bash
# commit-guard-zh 离线测试:对每个检查脚本喂正例(放行=0)/反例(拦截=2),断言退出码。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# assert <期望码> <说明> -- <命令...>
assert() {
  local want="$1" name="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else printf "${RED}  ✗ %s (期望 %s,实际 %s)${NC}\n" "$name" "$want" "$got"; fail=$((fail+1)); fi
}

echo "== secret-scan =="
# 正例:普通新增行
printf '+func main() {\n+  fmt.Println("hi")\n' > "$TMP/clean.diff"
assert 0 "干净 diff 放行" -- bash "$BIN/secret-scan.sh" "$TMP/clean.diff"
# 反例:AWS key / 私钥 / 密码赋值 / firebase
printf '+aws_key = "AKIAIOSFODNN7EXAMPLE"\n' > "$TMP/aws.diff"
assert 2 "AWS key 拦截" -- bash "$BIN/secret-scan.sh" "$TMP/aws.diff"
printf '+-----BEGIN RSA PRIVATE KEY-----\n+MIIabc\n' > "$TMP/pk.diff"
assert 2 "私钥块 拦截" -- bash "$BIN/secret-scan.sh" "$TMP/pk.diff"
printf '+  password = "s3cr3tP@ssw0rd12345"\n' > "$TMP/pw.diff"
assert 2 "密码赋值 拦截" -- bash "$BIN/secret-scan.sh" "$TMP/pw.diff"
printf '+  "type": "service_account",\n' > "$TMP/fb.diff"
assert 2 "firebase JSON 拦截" -- bash "$BIN/secret-scan.sh" "$TMP/fb.diff"
# 白名单豁免
printf '+EXAMPLE_KEY = "AKIAIOSFODNN7EXAMPLE"\n' > "$TMP/wl.diff"
assert 0 "白名单豁免" -- env SECRET_WHITELIST='EXAMPLE_KEY' bash "$BIN/secret-scan.sh" "$TMP/wl.diff"

echo "== gorm-mysql-check =="
cat > "$TMP/ok.go" <<'GO'
type User struct {
  Name string `gorm:"type:varchar(64);default:''"`
  Bio  string `gorm:"type:text"`
}
GO
assert 0 "合法 GORM 放行" -- bash "$BIN/gorm-mysql-check.sh" "$TMP/ok.go"
cat > "$TMP/bad.go" <<'GO'
type Msg struct {
  Body string `gorm:"type:text;default:''"`
}
GO
assert 2 "text+default 拦截" -- bash "$BIN/gorm-mysql-check.sh" "$TMP/bad.go"
cat > "$TMP/bad2.go" <<'GO'
type Doc struct {
  Meta string `gorm:"type:json;default:'{}'"`
}
GO
assert 2 "json+default 拦截" -- bash "$BIN/gorm-mysql-check.sh" "$TMP/bad2.go"

echo "== push-guard =="
assert 2 "推保护分支未确认 拦截" -- bash "$BIN/push-guard.sh" main
assert 0 "推保护分支已确认 放行" -- env COMMIT_GUARD_CONFIRM=1 bash "$BIN/push-guard.sh" main
assert 0 "推普通分支 放行" -- bash "$BIN/push-guard.sh" feature/x

echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
