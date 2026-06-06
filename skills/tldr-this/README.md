# tldr-this

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/tldr-this)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

把超长的文件 / PR / 文档 / 粘贴文本压成**中文 TL;DR + 关键点**,按输入类型给出补充分析。

## 安装

把本目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
# 全局(所有项目可用)
cp -r tldr-this ~/.claude/skills/

# 或 项目级(只在当前项目生效)
cp -r tldr-this .claude/skills/
```

**重启 Claude Code** 后即可触发。

## 用法

直接把内容丢给 Claude,说出触发词之一即可:

- `帮我总结这个`
- `太长了 tldr`
- `简单说一下这个`
- `/tldr-this`
- `这个 PR 改了啥`
- `这篇文章说了什么`

### 支持的输入类型

| 类型 | 示例 | 补充分析 |
| --- | --- | --- |
| 代码文件 | 粘贴源码 / 给文件路径 | 它做什么 / 主要入口 / 注意点 |
| PR / diff | 粘贴 diff 或 GitHub PR URL | 改了什么 / 影响面 / 风险 |
| 长文档 / 文章 | 粘贴正文或 URL | 核心结论 / 待办 |
| 粘贴的文本 | 会议纪要、邮件、设计方案等 | 核心结论 / 待办 |

### 输出结构示例

```markdown
**TL;DR**
一句话概括整个内容的核心。

**关键点**
- 关键点 1
- 关键点 2
- ...

**补充分析**（按类型）
- 代码文件:主要入口 / 注意点
- PR/diff:改了什么 / 影响面 / 风险
- 文档/文章:核心结论 / 待办
```

完整工作流、输出模板与硬规则见 [SKILL.md](./SKILL.md)。

## 硬规则摘要

- 忠于原文,不臆造不夸大
- 读不到的部分(截断、二进制)如实说明
- 保留关键数字、名词、代码标识符
- 产出中文(代码标识符/专有名词留英文)
- 可指出原文自相矛盾或可疑处

## License

[MIT](../../LICENSE)
