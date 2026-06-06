---
name: claude-code-zh
description: 把 Claude Code 汉化 —— 让 Claude 默认用中文回复,并给每个工具调用加中文 tooltip 提示。当用户想"汉化 Claude Code""让 Claude 说中文""装中文命令提示""localize Claude Code to Chinese"时使用。
---

# claude-code-zh —— Claude Code 中文化

## 能做什么 / 做不到什么

| 层级 | 能不能 | 说明 |
| --- | --- | --- |
| ① AI 全程中文回复 | ✅ | 写一段指令到 `~/.claude/CLAUDE.md`,所有 session 永久生效 |
| ② 命令中文 tooltip | ✅ | PostToolUse hook,跑命令后弹中文解释,不碰 Claude 本体 |
| ③ 界面 chrome(菜单/状态栏/`/config`) | ❌ | Claude Code v2.1.113+ 已是编译二进制,无 `cli.js`,字符串替换汉化方案全部失效。别尝试改二进制(会破坏代码签名 + 升级即失效)。 |

## 如何使用

### 一键安装
```bash
bash install.sh
```
- 把中文回复指令写进 `~/.claude/CLAUDE.md`(用 `<!-- claude-code-zh:begin/end -->` 标记包裹,可逆)
- 安装 `tool-tips-post.sh` 到 `~/.claude/hooks/`
- 用 python3 幂等地把 PostToolUse hook 写进 `~/.claude/settings.json`(安装前自动备份为 `settings.json.zh.bak`)

安装后**重启 Claude Code**,tooltip 才会加载;中文回复指令下个 session 全局生效。

### 卸载
```bash
bash uninstall.sh
```
干净移除三处改动(CLAUDE.md 区块、settings.json 条目、hook 脚本)。

## 工作原理

- **中文回复**:靠 `CLAUDE.md` 指令引导模型语言,不改任何二进制,零风险。
- **tooltip**:`tool-tips-post.sh` 从 stdin 读工具调用 JSON,识别 Bash/Read/Write/Edit/Grep/MCP 等,输出 `{"systemMessage":"🌸 ... 🌸"}`,Claude Code 把它显示给用户。脚本**只打印,不写文件、不联网、不执行下载内容**,`exit 0`。

## 自定义

- 嫌 tooltip 太吵:把 `settings.json` 里该 hook 的 `"matcher": ""` 改成 `"matcher": "Bash"`(只在跑命令时提示)。
- 改/加命令翻译:编辑 `~/.claude/hooks/tool-tips-post.sh` 里的 `desc_shell` 函数。
