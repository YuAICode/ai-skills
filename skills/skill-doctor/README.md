# skill-doctor

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/skill-doctor)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

发布前校验 skill 目录是否符合合集约定的 lint 工具。当用户说"检查 skill / lint skill / skill 规范校验 / 发布前检查"时触发。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r skill-doctor ~/.claude/skills/
```

## 📖 用法

在合集仓库根目录运行,检查单个 skill:

```bash
bash skill-doctor/bin/lint-skill.sh ./my-new-skill
```

遍历整个合集所有 skill:

```bash
for d in */; do
  [ -f "$d/SKILL.md" ] || continue
  bash skill-doctor/bin/lint-skill.sh "$d"
done
```

### 退出码

| 退出码 | 含义 |
|--------|------|
| `0` | 全部通过(或只有 warning) |
| `2` | 有 error 级问题须修复 |

### 检查项

| # | 级别 | 检查内容 |
|---|------|----------|
| 1 | error | 存在 `SKILL.md` |
| 2 | error | `SKILL.md` 有 YAML frontmatter 且含 `name:` 与 `description:` |
| 3 | error | frontmatter `name:` 值 == 目录名 |
| 4 | error | 存在 `README.md` |
| 5 | error | `README.md` 含 `img.shields.io` 徽章 |
| 6 | error | 有 `bin/*.sh` 时必须有 `tests/run.sh` |
| 7 | warning | `description` 建议含触发词 |

## 🧪 测试

```bash
bash skill-doctor/tests/run.sh
```

## 📄 License

[MIT](../../LICENSE)
