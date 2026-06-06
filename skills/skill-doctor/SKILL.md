---
name: skill-doctor
description: 发布前校验 skill 目录是否符合合集约定的 lint 工具。当用户说"检查 skill / lint skill / skill 规范校验 / 发布前检查"时触发。
---

# skill-doctor — skill 合集 lint 工具

发布一个 skill 前,用本工具确认它符合合集的目录约定(SKILL.md frontmatter、README 徽章、bin/tests 配对等)。

## 何时触发

用户说"检查 skill / lint skill / skill 规范校验 / 这个 skill 合规吗 / 发布前检查"。

## 用法

### 检查单个 skill

```bash
bash skill-doctor/bin/lint-skill.sh <skill目录路径>
```

示例(在合集根目录运行):

```bash
bash skill-doctor/bin/lint-skill.sh ./my-new-skill
```

### 遍历整个合集

```bash
for d in */; do
  [ -f "$d/SKILL.md" ] || continue
  bash skill-doctor/bin/lint-skill.sh "$d"
done
```

### 退出码说明

| 退出码 | 含义 |
|--------|------|
| `0` | 全部通过(或只有 warning) |
| `2` | 存在 error 级问题,阻止发布 |

### Error vs Warning

**Error(exit 2,须修复才能发布)**:

1. 缺少 `SKILL.md`
2. `SKILL.md` 没有 YAML frontmatter(缺 `---` 围栏),或 frontmatter 缺 `name:` / `description:`
3. frontmatter 的 `name:` 值与目录名不一致
4. 缺少 `README.md`
5. `README.md` 未包含 `img.shields.io` 徽章
6. 存在 `bin/` 目录且里面有 `.sh` 文件,却没有 `tests/run.sh`

**Warning(exit 0,建议改但不拦)**:

- `description` 为空或未含"触发"字样(建议 description 写明触发词)

## 边界

- 只检查目录结构与 frontmatter 格式,不校验 SKILL.md 内容质量。
- 不执行 `tests/run.sh`(只检查文件是否存在);要跑测试请单独执行。
- 纯 bash,零外部依赖。
