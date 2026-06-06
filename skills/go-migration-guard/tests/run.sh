#!/usr/bin/env bash
# go-migration-guard 测试:喂各类 diff 片段,断言退出码与输出内容。
# 离线,不依赖真实 git repo。
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$DIR/../bin/check-migration.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# assert_exit <期望退出码> <测试名> -- <命令...>
assert_exit() {
  local want="$1" name="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (期望 exit %s,实际 exit %s)${NC}\n" "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# assert_output_contains <期望字符串> <测试名> -- <命令...>
assert_output_contains() {
  local want="$1" name="$2"; shift 3
  local out
  out="$("$@" 2>&1 || true)"
  if printf '%s' "$out" | grep -qF "$want"; then
    printf "${GREEN}  ✓ %s${NC}\n" "$name"; pass=$((pass+1))
  else
    printf "${RED}  ✗ %s (输出中未找到: %s)${NC}\n" "$name" "$want"
    fail=$((fail+1))
  fi
}

write_diff() {
  local file="$1"; shift
  printf '%s\n' "$@" > "$file"
}

# ============================================================
# 反例1:普通 diff,无 gorm 字段变更 → exit 0
# ============================================================
echo "== 反例1:无 gorm 字段变更 =="
DIFF1="$TMP/no_gorm.diff"
write_diff "$DIFF1" \
  'diff --git a/main.go b/main.go' \
  'index 1234567..abcdefg 100644' \
  '--- a/main.go' \
  '+++ b/main.go' \
  '@@ -10,3 +10,4 @@' \
  ' func main() {' \
  '+	fmt.Println("hello")' \
  ' }'

assert_exit 0 "普通代码改动放行(exit 0)" -- bash "$BIN" --diff "$DIFF1"

# ============================================================
# 反例2:空 diff → exit 0
# ============================================================
echo "== 反例2:空 diff =="
DIFF2="$TMP/empty.diff"
printf '' > "$DIFF2"

assert_exit 0 "空 diff 放行(exit 0)" -- bash "$BIN" --diff "$DIFF2"

# ============================================================
# 反例3:只有 json tag,无 gorm tag → exit 0
# ============================================================
echo "== 反例3:只有 json tag,无 gorm tag =="
DIFF3="$TMP/json_only.diff"
write_diff "$DIFF3" \
  'diff --git a/model/user.go b/model/user.go' \
  'index 7777777..8888888 100644' \
  '--- a/model/user.go' \
  '+++ b/model/user.go' \
  '@@ -3,3 +3,4 @@' \
  '+	Nickname string `json:"nickname"`' \
  ' }'

assert_exit 0 "只有 json tag 无 gorm tag 的字段放行(exit 0)" -- bash "$BIN" --diff "$DIFF3"

# ============================================================
# 正例1:新增含 gorm tag 的字段,无迁移线索 → exit 2 + 强提醒
# ============================================================
echo "== 正例1:新增 gorm 字段,无迁移线索 =="
DIFF4="$TMP/add_gorm_field.diff"
write_diff "$DIFF4" \
  'diff --git a/model/user.go b/model/user.go' \
  'index 1111111..2222222 100644' \
  '--- a/model/user.go' \
  '+++ b/model/user.go' \
  '@@ -5,4 +5,5 @@ type User struct {' \
  ' 	ID   uint   `gorm:"primaryKey"`' \
  '+	Name string `gorm:"type:varchar(64)"`' \
  ' }'

assert_exit 2 "新增 gorm 字段命中(exit 2)" -- bash "$BIN" --diff "$DIFF4"
assert_output_contains 'Name string' "输出中列出 Name 字段" -- bash "$BIN" --diff "$DIFF4"
assert_output_contains '未发现任何迁移线索' "无迁移线索时给出更强提醒" -- bash "$BIN" --diff "$DIFF4"

# ============================================================
# 正例2:删除含 gorm tag 的字段 → exit 2
# ============================================================
echo "== 正例2:删除 gorm 字段 =="
DIFF5="$TMP/remove_gorm_field.diff"
write_diff "$DIFF5" \
  'diff --git a/model/order.go b/model/order.go' \
  'index aaaaaaa..bbbbbbb 100644' \
  '--- a/model/order.go' \
  '+++ b/model/order.go' \
  '@@ -8,5 +8,4 @@ type Order struct {' \
  ' 	ID        uint   `gorm:"primaryKey"`' \
  '-	OldField  string `gorm:"column:old_field"`' \
  ' }'

assert_exit 2 "删除 gorm 字段命中(exit 2)" -- bash "$BIN" --diff "$DIFF5"
assert_output_contains 'OldField' "输出中列出删除的字段" -- bash "$BIN" --diff "$DIFF5"

# ============================================================
# 正例3:gorm 字段改动 + migration 目录改动 → exit 2 + 线索提示
# ============================================================
echo "== 正例3:gorm 字段改动 + migration 目录改动 =="
DIFF6="$TMP/with_migration.diff"
write_diff "$DIFF6" \
  'diff --git a/migrations/20240601_add_name.go b/migrations/20240601_add_name.go' \
  'new file mode 100644' \
  'index 0000000..1111111' \
  '--- /dev/null' \
  '+++ b/migrations/20240601_add_name.go' \
  '@@ -0,0 +1,3 @@' \
  '+package migrations' \
  '+func Up(db *gorm.DB) { db.Exec("ALTER TABLE users ADD COLUMN name VARCHAR(64)") }' \
  'diff --git a/model/user.go b/model/user.go' \
  'index 2222222..3333333 100644' \
  '--- a/model/user.go' \
  '+++ b/model/user.go' \
  '@@ -5,4 +5,5 @@ type User struct {' \
  ' 	ID   uint   `gorm:"primaryKey"`' \
  '+	Name string `gorm:"type:varchar(64)"`' \
  ' }'

assert_exit 2 "有迁移线索时仍 exit 2(需人工确认)" -- bash "$BIN" --diff "$DIFF6"
assert_output_contains 'migration 目录改动' "检测到 migration 目录线索" -- bash "$BIN" --diff "$DIFF6"

# ============================================================
# 正例4:gorm 字段改动 + AutoMigrate 新增 → 检测到线索
# ============================================================
echo "== 正例4:gorm 字段改动 + AutoMigrate 线索 =="
DIFF7="$TMP/with_automigrate.diff"
write_diff "$DIFF7" \
  'diff --git a/model/user.go b/model/user.go' \
  'index 4444444..5555555 100644' \
  '--- a/model/user.go' \
  '+++ b/model/user.go' \
  '@@ -5,4 +5,5 @@ type User struct {' \
  '+	Score int `gorm:"default:0"`' \
  ' }' \
  'diff --git a/main.go b/main.go' \
  'index 6666666..7777777 100644' \
  '--- a/main.go' \
  '+++ b/main.go' \
  '@@ -20,2 +20,3 @@' \
  '+	db.AutoMigrate(&User{})' \
  ' }'

assert_exit 2 "AutoMigrate 线索时仍 exit 2(需确认)" -- bash "$BIN" --diff "$DIFF7"
assert_output_contains 'AutoMigrate' "检测到 AutoMigrate 线索" -- bash "$BIN" --diff "$DIFF7"

# ============================================================
# 正例5:多字段变更,验证都被列出
# ============================================================
echo "== 正例5:多字段变更 =="
DIFF8="$TMP/multi_fields.diff"
write_diff "$DIFF8" \
  'diff --git a/model/post.go b/model/post.go' \
  'index 9999999..aaaaaaa 100644' \
  '--- a/model/post.go' \
  '+++ b/model/post.go' \
  '@@ -4,5 +4,7 @@ type Post struct {' \
  ' 	ID uint `gorm:"primaryKey"`' \
  '-	Title string `gorm:"size:255"`' \
  '+	Title   string `gorm:"size:512"`' \
  '+	Content string `gorm:"type:varchar(2000)"`' \
  ' }'

assert_exit 2 "多字段变更命中(exit 2)" -- bash "$BIN" --diff "$DIFF8"
assert_output_contains 'Title' "输出中含 Title 字段" -- bash "$BIN" --diff "$DIFF8"
assert_output_contains 'Content' "输出中含 Content 字段" -- bash "$BIN" --diff "$DIFF8"

# ============================================================
echo ""
printf "结果:${GREEN}%d 通过${NC} / ${RED}%d 失败${NC}\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
