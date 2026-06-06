#!/usr/bin/env bash
# 把 commit-guard-zh 的检查装成目标 repo 的 git pre-commit / pre-push hook。
# 用法:在目标 repo 里跑   bash /path/to/commit-guard-zh/install.sh
#       或              bash install.sh <目标repo路径>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$PWD}"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

GIT_DIR="$(git -C "$TARGET" rev-parse --git-dir 2>/dev/null)" || { echo "❌ $TARGET 不是 git 仓库"; exit 1; }
# git-dir 可能是相对路径,转绝对
case "$GIT_DIR" in /*) ;; *) GIT_DIR="$TARGET/$GIT_DIR";; esac
HOOKS="$GIT_DIR/hooks"
CG="$HOOKS/commit-guard"
mkdir -p "$CG"

# 1) 拷检查脚本
cp "$SCRIPT_DIR/bin/"*.sh "$CG/"
chmod 755 "$CG/"*.sh
printf "${GREEN}✅ 已拷检查脚本 → %s${NC}\n" "$CG"

# 2) 装 hook(若已存在且非本工具的,备份)
install_hook() {
  local name="$1"
  local dest="$HOOKS/$name"
  if [ -e "$dest" ] && ! grep -q "commit-guard-zh" "$dest" 2>/dev/null; then
    cp "$dest" "$dest.pre-commit-guard.bak"
    printf "${YELLOW}⚠️  已存在 %s,备份为 %s.pre-commit-guard.bak${NC}\n" "$name" "$name"
  fi
  cp "$SCRIPT_DIR/hooks/$name" "$dest"
  chmod 755 "$dest"
  printf "${GREEN}✅ 已装 hook → %s${NC}\n" "$dest"
}
install_hook pre-commit
install_hook pre-push

# 3) 放一份 config 示例(不覆盖已有的)
if [ ! -f "$TARGET/.commit-guard.sh" ]; then
  cp "$SCRIPT_DIR/config.example.sh" "$TARGET/.commit-guard.sh"
  printf "${GREEN}✅ 已生成 %s（按需改;可加进 .gitignore 或提交)${NC}\n" "$TARGET/.commit-guard.sh"
fi

echo
printf "${GREEN}完成。${NC}以后该 repo 的 commit/push 会自动跑检查。\n"
echo "卸载:bash $SCRIPT_DIR/uninstall.sh \"$TARGET\""
