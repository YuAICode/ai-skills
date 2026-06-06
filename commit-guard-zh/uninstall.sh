#!/usr/bin/env bash
# 卸载 commit-guard-zh 的 git hook。用法:bash uninstall.sh [目标repo路径]
set -euo pipefail
TARGET="${1:-$PWD}"
GREEN='\033[0;32m'; NC='\033[0m'
GIT_DIR="$(git -C "$TARGET" rev-parse --git-dir 2>/dev/null)" || { echo "❌ 不是 git 仓库"; exit 1; }
case "$GIT_DIR" in /*) ;; *) GIT_DIR="$TARGET/$GIT_DIR";; esac
HOOKS="$GIT_DIR/hooks"

for name in pre-commit pre-push; do
  dest="$HOOKS/$name"
  if [ -e "$dest" ] && grep -q "commit-guard-zh" "$dest" 2>/dev/null; then
    if [ -e "$dest.pre-commit-guard.bak" ]; then
      mv "$dest.pre-commit-guard.bak" "$dest"
      printf "${GREEN}✅ 已恢复原 %s${NC}\n" "$name"
    else
      rm -f "$dest"
      printf "${GREEN}✅ 已移除 %s${NC}\n" "$name"
    fi
  fi
done
rm -rf "$HOOKS/commit-guard"
printf "${GREEN}✅ 已删检查脚本目录${NC}\n"
echo "（.commit-guard.sh 保留,如不需要请自行删除）"
