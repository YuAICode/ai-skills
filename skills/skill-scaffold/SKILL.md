---
name: skill-scaffold
description: 一键生成新 Claude Code skill 的标准骨架(SKILL.md + 带徽章的 README + 可选 bin/tests/hooks)。当用户说"建一个新 skill / 起个 skill 骨架 / scaffold a skill / 加个 skill 到合集"时触发。自动从 git remote 解析 ORG/REPO 填好徽章。
---

# skill-scaffold — 新 skill 脚手架

把一套 skill 已收敛的目录约定(frontmatter、徽章、章节、测试框架)固化成生成器,起新 skill 不用从零拷。

## 何时触发

用户说"建个新 skill / 起骨架 / 往合集加一个 skill / scaffold"。

## 用法

1. 问清:**skill 名**(kebab-case)、**一句话中文描述**(会进 frontmatter 的 description,要含触发词)、是否需要 **bin/脚本**(确定性检查类)或 **hooks**。
2. 在合集仓库根目录跑:
   ```bash
   bash <skill>/bin/new-skill.sh <name> "<中文描述>" [--bin] [--hooks]
   ```
3. 脚本生成 `<name>/SKILL.md`、`<name>/README.md`(徽章 URL 已按 git remote 自动填好),`--bin` 再带 `bin/` + `tests/run.sh` 骨架。
4. 按脚本末尾打印的那行,把索引加到顶层 README 表格。
5. **帮用户填肉**:补 SKILL.md 的「何时触发/用法/边界」、README 的用法,以及(如有)bin 脚本与测试。

## 边界

- 只生成骨架,不写业务逻辑(那一步由 Claude 接着填)。
- 目录已存在则拒绝覆盖;名字非 kebab-case 直接报错。
- 解析不到 git remote 时徽章用 `YOUR_ORG/YOUR_REPO` 占位,可手改。
