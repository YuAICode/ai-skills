#!/usr/bin/env bash
# add-license.sh — 生成开源 LICENSE 文件
# 用法:
#   add-license.sh <SPDX-ID> [author] [year] [--dir 目录] [--force]
#   例:add-license.sh MIT "Alice" 2026
# 支持(内置可填充正文):MIT ISC BSD-2-Clause BSD-3-Clause Unlicense
# 长篇 copyleft(Apache-2.0 / GPL-3.0 等)给官方指引,不在此填充。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DIR="$SCRIPT_DIR/../templates"

id=""; author=""; year=""; dir="."; force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="$2"; shift 2;;
    --force) force=1; shift;;
    -*) echo "未知参数:$1" >&2; exit 1;;
    *) if [ -z "$id" ]; then id="$1"; elif [ -z "$author" ]; then author="$1"; elif [ -z "$year" ]; then year="$1"; fi; shift;;
  esac
done

[ -n "$id" ] || { echo "用法:add-license.sh <SPDX-ID> [author] [year] [--dir] [--force]" >&2; exit 1; }

# 长篇 copyleft:给指引,不填充
case "$id" in
  Apache-2.0)
    echo "ℹ️  Apache-2.0 正文较长且应逐字使用。获取完整文本:" >&2
    echo "   https://www.apache.org/licenses/LICENSE-2.0.txt" >&2
    echo "   另需在源码文件头加 Apache notice(见该页附录)。" >&2
    exit 0;;
  GPL-3.0|GPL-3.0-only|GPL-3.0-or-later)
    echo "ℹ️  GPL-3.0 是 copyleft 且正文很长,应逐字使用官方文本:" >&2
    echo "   https://www.gnu.org/licenses/gpl-3.0.txt" >&2
    exit 0;;
esac

tpl="$TPL_DIR/$id.txt"
if [ ! -f "$tpl" ]; then
  echo "❌ 不支持的协议:$id" >&2
  echo "   内置可填充:$(cd "$TPL_DIR" && ls *.txt 2>/dev/null | sed 's/\.txt$//' | tr '\n' ' ')" >&2
  echo "   copyleft 指引:Apache-2.0 / GPL-3.0" >&2
  exit 1
fi

[ -n "$author" ] || author="$(git config user.name 2>/dev/null || echo 'YOUR NAME')"
[ -n "$year" ] || year="$(date +%Y)"

out="$dir/LICENSE"
if [ -e "$out" ] && [ "$force" != "1" ]; then
  echo "❌ $out 已存在(加 --force 覆盖)" >&2
  exit 1
fi

# 填充占位符([year] [fullname]),用 awk 避免 sed 转义问题
awk -v y="$year" -v n="$author" '{
  gsub(/\[year\]/, y); gsub(/\[fullname\]/, n); print
}' "$tpl" > "$out"

echo "✅ 已生成 ${out} ( ${id} / ${author} / ${year} )"
