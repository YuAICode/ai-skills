---
name: gitignore-doctor
description: 揪出已被 git 追踪或即将提交的垃圾文件,给 .gitignore 追加建议。当用户说「检查 gitignore / gitignore 有问题 / 哪些文件不该提交 / 帮我清理 gitignore / .DS_Store 被提交了 / node_modules 进了 git」时触发。
---

# gitignore-doctor — .gitignore 诊断与修复助手

揪出已被 git 追踪或未被忽略的垃圾文件(node_modules、.env、.DS_Store 等),输出两组清单 + 建议追加到 .gitignore 的内容,**在用户确认后**再执行清理。

## 何时触发

用户说以下任意一种:
- "检查一下 gitignore / .gitignore 有没有问题"
- "哪些文件不该提交 / 哪些文件漏加 .gitignore 了"
- "帮我清理 gitignore / 修一下 .gitignore"
- ".DS_Store / node_modules / .env 被 git 追踪了"
- "git 里有垃圾文件"

## 工作流

### 1. 跑诊断脚本(只读,不修改任何东西)

```bash
bash <skill>/bin/check.sh [项目目录]   # 默认当前目录
```

脚本退出码含义:
- `exit 0` — 无已追踪的垃圾(可能有"建议加 .gitignore"的提示)
- `exit 2` — 发现已被 git 追踪的垃圾文件,需要清理
- `exit 1` — 不是 git 仓库

### 2. 用中文解释结果

把脚本输出的两组清单翻译成用户可读的说明:

**若有「已被追踪的垃圾文件」(exit 2)**:
- 逐文件说明为什么它不应该被追踪
- 给出完整的清理命令,例如:
  ```bash
  git rm --cached .DS_Store
  git rm --cached -r node_modules/
  ```
- 给出建议追加到 `.gitignore` 的内容块

**若只有「建议加进 .gitignore」(exit 0)**:
- 说明这些文件当前未被追踪也未被忽略,存在将来误 add 的风险
- 给出建议追加的 .gitignore 内容块

### 3. 征得用户同意后执行

**不要**在用户确认前执行任何 `git rm --cached` 或修改 `.gitignore`。
等用户说"好 / 执行 / 可以"后再逐步执行:

1. 执行 `git rm --cached` 命令(如有已追踪垃圾)
2. 将建议内容追加到 `.gitignore`
3. 提示用户确认 `git add .gitignore` 并重新 commit

## 检测的垃圾模式

| 模式 | 说明 |
|------|------|
| `node_modules/` | Node.js 依赖,不应提交 |
| `dist/` / `build/` | 构建产物 |
| `.env` / `.env.*` | 环境变量/密钥文件 |
| `.DS_Store` | macOS 系统文件 |
| `*.log` | 日志文件 |
| `__pycache__/` / `*.pyc` | Python 编译缓存 |
| `.idea/` / `.vscode/` | IDE 配置(建议个人 global gitignore) |
| `coverage/` | 测试覆盖率报告 |
| `*.class` | Java 编译产物 |
| `target/` | Maven/Cargo 构建目录 |
| `vendor/` | Go/PHP 依赖(视项目而定) |
| `.gradle/` | Gradle 缓存 |
| `Pods/` | iOS CocoaPods 依赖 |

## 边界

- 脚本本身**只读**:不修改任何文件、不执行任何 git 写操作。
- 不扫历史提交,只看当前 `git ls-files` 输出与工作区状态。
- `vendor/` 在 Go 项目里有时需要提交(Go mod vendor),执行前请与用户确认。
- 不联网、不需要外部依赖(纯 bash + git + grep)。
