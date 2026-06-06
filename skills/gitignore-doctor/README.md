# gitignore-doctor 🩺

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/gitignore-doctor)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

揪出已被 git 追踪或未被忽略的垃圾文件(node_modules、.env、.DS_Store 等),输出清单 + 建议追加到 `.gitignore` 的内容,**征得用户同意后**再执行清理。

## ✨ 能做什么

| 检查 | 做什么 |
|------|--------|
| **已追踪垃圾** | `git ls-files` 里命中垃圾模式的文件 → 列出 + 给 `git rm --cached` 命令 |
| **未忽略垃圾** | 工作区里未被追踪、也未被忽略的垃圾文件 → 建议加 .gitignore |
| **追加建议** | 根据命中情况生成可直接复制进 `.gitignore` 的内容块 |

> 零外部依赖(纯 bash + git + grep)。脚本本身只读,不修改任何文件。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r gitignore-doctor ~/.claude/skills/
```

## 📖 用法

### A. 作为 Claude Code skill(推荐)

跟 Claude 说以下任意一种,即可触发:

- "检查一下 gitignore"
- "帮我清理 .gitignore"
- ".DS_Store 被 git 追踪了"
- "node_modules 怎么进了 git"

Claude 会跑脚本 → 用中文解释结果 → 给出清理命令和 .gitignore 追加内容 → 征得你同意后执行。

### B. 直接运行脚本

```bash
# 检查当前目录(必须是 git 仓库)
bash gitignore-doctor/bin/check.sh

# 检查指定目录
bash gitignore-doctor/bin/check.sh /path/to/your-project
```

**退出码:**
- `0` — 无已追踪的垃圾(可能有建议)
- `2` — 发现已被 git 追踪的垃圾,需清理
- `1` — 不是 git 仓库

## 🎯 检测的垃圾模式

`node_modules/` · `dist/` · `build/` · `.env` / `.env.*` · `.DS_Store` · `*.log` · `__pycache__/` · `*.pyc` · `.idea/` · `.vscode/` · `coverage/` · `*.class` · `target/` · `vendor/` · `.gradle/` · `Pods/`

## 🧪 测试

```bash
bash tests/run.sh   # 离线,临时 git repo,验证退出码与输出
```

## 📄 License

[MIT](../../LICENSE)
