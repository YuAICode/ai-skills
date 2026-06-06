# error-explain-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/error-explain-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

粘贴任意语言的报错/堆栈/panic/exception,得到**中文根因分析 + 可操作修复建议**。
跨语言通用:Go / JavaScript / Python / Java / Rust / Flutter / Dart / Shell / …

## 安装

把本目录拷进 Claude Code 的 skills 目录:

```bash
# 全局(所有项目可用)
cp -r error-explain-zh ~/.claude/skills/

# 或 项目级(只在当前项目生效)
cp -r error-explain-zh .claude/skills/
```

**重启 Claude Code** 后即可触发。

## 用法

直接把报错粘给 Claude,说出触发词之一即可:

- `帮我看这个报错`
- `这个错误是什么意思`
- `这个 panic 怎么回事`
- `帮我 debug`

Claude 会按固定工作流输出:

```markdown
## 错误类型
Go — 空指针 panic

## 根因
...

## 修复建议
### 主要修复
1. ...
   - 验证方法: ...

## 还需补充
（信息充分时省略）
```

完整工作流、输出模板与硬规则见 [SKILL.md](./SKILL.md)。

### 支持的场景

| 语言/运行时 | 典型错误形式 |
| --- | --- |
| Go | `goroutine … panic:` |
| Python | `Traceback (most recent call last)` |
| Node.js/JS | `UnhandledPromiseRejection` / `TypeError` |
| Java/Kotlin | `Exception in thread "main"` / `Caused by:` |
| Rust | `thread 'main' panicked at` |
| Flutter/Dart | `══╡ EXCEPTION CAUGHT BY FLUTTER FRAMEWORK` |
| Shell | `bash: command not found` / `exit code N` |

> 与 `lambda-logs-zh` 的区别:`lambda-logs-zh` 专门处理 AWS CloudWatch 多条日志的聚类分析;本 skill 是**通用单次报错诊断**,不限运行时和平台。

## 硬规则摘要

- 不臆断行号外的代码
- 区分"确定根因"vs"可能原因"
- 指出用户代码帧 vs 库/运行时帧
- 报错含密钥/PII 时提醒打码
- 信息不足时明确追问,不编造

## License

[MIT](../LICENSE)
