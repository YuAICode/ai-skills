#!/usr/bin/env bash
# find-stale-docs.sh — 找出可能因代码改动而过期的文档候选
# 用法:
#   find-stale-docs.sh [base]
#     base: 对比基点,默认自动探测 origin/HEAD → origin/main → origin/master → main → master
#     例:find-stale-docs.sh origin/main
#         find-stale-docs.sh v1.2.0
# 输出:CHANGED_FILES、SEARCH_SCOPE、STALE_DOCS(候选文档路径列表)
# 依赖:git + grep(纯内置,零外部依赖)。兼容 bash 3.2(macOS 系统 bash)。
set -uo pipefail

# ---- 探测仓库根 ----
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: 当前目录不在 git 仓库中,请在仓库目录下运行。" >&2
  exit 1
}

# ---- 确定 base ----
base="${1:-}"
if [ -z "$base" ]; then
  # 自动探测:依次尝试 origin/HEAD → origin/main → origin/master → main → master
  for candidate in "origin/HEAD" "origin/main" "origin/master" "main" "master"; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      base="$candidate"
      break
    fi
  done
fi
if [ -z "$base" ]; then
  echo "ERROR: 无法自动探测基点(remote 不存在或本地无 main/master 分支),请手动传入 base 参数。" >&2
  exit 1
fi

# ---- 验证 base 是合法 git ref ----
if ! git rev-parse --verify "${base}" >/dev/null 2>&1; then
  echo "ERROR: 基点 '${base}' 不是有效的 git ref,请检查拼写。" >&2
  exit 1
fi

# ---- 取改动文件列表(兼容 bash 3.2,用 while read 代替 mapfile)----
changed=()
while IFS= read -r line; do
  [ -n "$line" ] && changed+=("$line")
done < <(git diff --name-only "${base}..HEAD" 2>/dev/null || true)

if [ "${#changed[@]}" -eq 0 ]; then
  echo "CHANGED_FILES: (无改动)"
  echo "STALE_DOCS: (无改动文件,无候选文档)"
  exit 0
fi

echo "BASE: $base"
echo "CHANGED_FILES:"
for f in "${changed[@]}"; do
  echo "  $f"
done
echo ""

# ---- 收集文档文件范围(git 追踪的 *.md 文件) ----
doc_files=()
while IFS= read -r line; do
  [ -n "$line" ] && doc_files+=("$line")
done < <(git -C "$REPO_ROOT" ls-files '*.md' 2>/dev/null | sort -u)

if [ "${#doc_files[@]}" -eq 0 ]; then
  echo "SEARCH_SCOPE: (仓库中未找到 Markdown 文档)"
  echo "STALE_DOCS: (无文档可检查)"
  exit 0
fi

echo "SEARCH_SCOPE: ${#doc_files[@]} 个 Markdown 文档"

# ---- 对每个改动文件提取搜索关键词 ----
# 关键词 = basename(去扩展名) + 完整相对路径(不含 ./ 前缀)
keywords=()
for f in "${changed[@]}"; do
  base_no_ext="$(basename "$f" | sed 's/\.[^.]*$//')"
  # 避免太短的词(单字母/纯数字)引起大量误报
  if [ ${#base_no_ext} -ge 2 ] && printf '%s' "$base_no_ext" | grep -qvE '^[0-9]+$'; then
    keywords+=("$base_no_ext")
  fi
  # 完整路径也作为关键词(去掉 ./ 前缀)
  clean_path="${f#./}"
  keywords+=("$clean_path")
done

# 去重(兼容 bash 3.2)
if [ "${#keywords[@]}" -gt 0 ]; then
  dedup=()
  while IFS= read -r line; do
    [ -n "$line" ] && dedup+=("$line")
  done < <(printf '%s\n' "${keywords[@]}" | sort -u)
  keywords=("${dedup[@]}")
fi

if [ "${#keywords[@]}" -eq 0 ]; then
  echo ""
  echo "STALE_DOCS: (未能从改动文件中提取有效关键词)"
  exit 0
fi

# ---- grep 每个文档,看是否引用了任一关键词 ----
stale_docs=()
for doc in "${doc_files[@]}"; do
  doc_abs="$REPO_ROOT/$doc"
  [ -f "$doc_abs" ] || continue
  for kw in "${keywords[@]}"; do
    # -F 固定字符串(不做正则),避免特殊字符副作用
    if grep -qF "$kw" "$doc_abs" 2>/dev/null; then
      stale_docs+=("$doc")
      break  # 一个文档命中一次就够了
    fi
  done
done

echo ""
echo "STALE_DOCS: ${#stale_docs[@]} 个候选"
if [ "${#stale_docs[@]}" -gt 0 ]; then
  for doc in "${stale_docs[@]}"; do
    # 找出命中了哪些关键词,方便 Claude 判断
    matched_kws=()
    for kw in "${keywords[@]}"; do
      if grep -qF "$kw" "$REPO_ROOT/$doc" 2>/dev/null; then
        matched_kws+=("$kw")
      fi
    done
    echo "  $doc  (引用: ${matched_kws[*]})"
  done
else
  echo "  (没有文档引用了任何改动文件,文档可能已是最新或尚未记录这些文件)"
fi
