# claude-code-zh 🌸

把 **Claude Code 汉化**——让 Claude 默认用中文回复,并给每个工具调用加中文 tooltip 提示。

> 适用于 Claude Code v2.1.113+(编译二进制版)。这些新版本里,所有"字符串替换界面汉化"工具都已失效;本仓库只保留**可靠、可逆、零风险**的两件事。

## ✨ 功能

| 层级 | 状态 | 说明 |
| --- | --- | --- |
| ① **AI 全程中文回复** | ✅ | 一段指令写进 `~/.claude/CLAUDE.md`,所有 session 永久生效。代码/commit/专有名词保持英文。 |
| ② **命令中文 tooltip** | ✅ | PostToolUse hook,跑 `git`/`npm`/`docker` 等命令后弹中文解释。100+ 常用命令。 |
| ③ ~~界面 chrome 汉化~~ | ❌ | 菜单/状态栏/`/config` 面板。Claude Code v2.1.113+ 已编译成二进制,无 `cli.js`,**技术上不可行**——别改二进制(破坏代码签名 + 升级即丢)。 |

效果示例(tooltip):

```
🌸 🖥️ 执行命令: git push origin main — 把本地代码上传到远程仓库 🌸
🌸 📖 读取文件: app.py — 查看这个文件里写了什么 🌸
```

## 🚀 安装

```bash
git clone https://github.com/YuAICode/ai-skills.git
cd ai-skills/claude-code-zh
bash install.sh
```

安装脚本会:
1. 把中文回复指令写进 `~/.claude/CLAUDE.md`(`<!-- claude-code-zh:begin/end -->` 标记包裹,可逆);
2. 装 `tool-tips-post.sh` 到 `~/.claude/hooks/`;
3. 用 python3 幂等地把 PostToolUse hook 写进 `~/.claude/settings.json`(安装前自动备份 `settings.json.zh.bak`)。

> ⚠️ 安装后**重启 Claude Code**,tooltip 才加载。中文回复指令下个 session 全局生效。
> 依赖:`bash` + `python3`(用来安全地改 JSON,不用脆弱的 sed)。

### 作为 Claude Code skill 使用(可选)

把整个目录放到 `~/.claude/skills/claude-code-zh/`,然后跟 Claude 说"汉化 Claude Code"即可触发(见 `SKILL.md`)。

## 🧹 卸载

```bash
bash uninstall.sh
```

干净移除三处改动:CLAUDE.md 区块、settings.json 条目、hook 脚本。

## 🔘 一键开关 tooltip

安装后会注册一个 `tooltip` 命令(zsh/bash 别名),随时开关,关闭只是从 `settings.json` 摘掉条目、不删脚本:

```bash
tooltip            # 切换(开↔关)
tooltip on         # 开启
tooltip off        # 关闭
tooltip status     # 查看当前状态
```

> 改动 settings.json 后需**重启 Claude Code** 生效。别名在**新开的终端**里可用。

## ⚙️ 自定义

- **只在跑命令时提示**(更安静):把 `~/.claude/settings.json` 里该 hook 的 `"matcher": ""` 改成 `"matcher": "Bash"`。
- **改/加命令翻译**:编辑 `~/.claude/hooks/tool-tips-post.sh` 的 `desc_shell` 函数。

## 📄 License

[MIT](./LICENSE)
