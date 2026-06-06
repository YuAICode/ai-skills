---
name: readme-init
description: 扫描项目自动生成或刷新 README(检测技术栈/结构/可运行脚本)。用户说「/readme-init」「帮我生成 README」「项目没有 README,帮我写一个」「刷新/更新 README」「README 太旧了帮我刷新」时触发。
---

# readme-init — 项目 README 自动生成 / 刷新

扫描目标项目的技术栈、入口文件、可运行脚本、目录结构,据此让 Claude 撰写或刷新一份中文 README。
核心原则:**只写扫描到的真实事实,拿不准的标「待补」,不臆造功能或命令**。

## 何时触发

用户说以下任意一种:

- `/readme-init` 或 `/readme-init <项目目录>`
- "帮我生成 README" / "这个项目没有 README,帮我写一个"
- "刷新/更新 README" / "README 太旧了/不准了"
- "给这个仓库补一份文档"

## 用法

### 1. 扫描项目

```bash
bash <skill>/bin/scan-project.sh [项目目录]
# 默认当前目录;输出四个段落:
#   LANGUAGES   — 检测到的编程语言/运行时
#   SCRIPTS     — package.json / Makefile / composer.json 中可运行命令
#   ENTRYPOINTS — 存在的常见入口文件
#   STRUCTURE   — 顶层目录与关键文件(忽略 node_modules/.git/dist/build 等)
```

### 2. 流程

1. **扫描**:跑 `bin/scan-project.sh <项目目录>`,拿到结构化事实。
2. **判断是否已有 README**:
   - **无 README**:按下方模板从零生成。
   - **已有 README**:先读原文,在尊重原有内容的基础上,仅补缺/更新与扫描结果不符的部分,不全量覆盖。
3. **写 README**:依据扫描事实填充模板各节。拿不准的内容一律标 `（待补）`。
4. **写入文件**:默认写到 `<项目目录>/README.md`;若已有 README 则在确认后覆盖。
5. **报告**:列出已填写的章节、标为「待补」的项目。

### README 模板(新建时使用)

```markdown
# <项目名>

> <一句话简介>（待补:请补充项目用途）

## 技术栈

- <语言/框架>(来自 LANGUAGES 扫描)

## 安装

```bash
# 待补:根据项目实际安装步骤填写
```

## 运行

```bash
# 来自 SCRIPTS 扫描,如:
# npm run build
# make test
```

## 项目结构

```
<来自 STRUCTURE 扫描,列顶层目录与关键文件>
```

## 许可

（待补:未检测到 LICENSE 文件,请补充）
```

## 硬规则

1. **基于事实**:只写扫描到的语言、脚本、文件。未扫描到的功能/命令不得出现。
2. **拿不准就标「待补」**:项目简介、作者、许可等无法自动推断的内容,一律用 `（待补）` 占位。
3. **已有 README 尊重原文**:补缺优先,改动最小化;不删除原有人工内容。
4. **不执行脚本**:只读取/解析文件,不运行任何项目构建或测试命令。
5. **中文输出**:生成的 README 使用简体中文;代码块、路径、命令保持英文。

## 边界

- `bin/scan-project.sh` 纯 bash + grep,无需 jq/python/node 等外部工具,离线可用。
- 不自动 push/commit;写完后告知用户文件路径,由用户决定是否提交。
- 不处理多 repo monorepo 的子包递归扫描;只扫单一项目根目录。
- 框架/语言靠清单文件推断,无清单文件的项目会尝试文件扩展名兜底(maxdepth 3)。
