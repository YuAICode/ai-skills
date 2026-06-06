# dep-audit

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/dep-audit)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

扫项目依赖清单,报过期/有风险的依赖,给中文升级摘要——只读,不自动改清单。支持 npm / Go / Flutter / Python 四个生态。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r dep-audit ~/.claude/skills/
```

## 用法

跟 Claude 说**"检查依赖 / 依赖过期了吗 / 扫依赖"**,它会:
1. 跑 `bin/audit.sh` 探测清单并调用各生态的 outdated 命令
2. 把原始输出整理成中文摘要(可安全升 / 大版本需谨慎 / 已知风险提示)
3. 给出升级建议——不自动修改任何文件

也可单独跑脚本:

```bash
# 扫当前目录
bash dep-audit/bin/audit.sh

# 扫指定项目目录
bash dep-audit/bin/audit.sh /path/to/my-project
```

### 环境变量覆盖(测试或自定义工具路径)

| 变量 | 覆盖的工具 | 默认值 |
| ----------- | ----------------- | ----------- |
| `NPM_CLI` | npm 命令 | `npm` |
| `GO_CLI` | go 命令 | `go` |
| `FLUTTER_CLI` | flutter 命令 | `flutter` |
| `PIP_CLI` | pip 命令 | `pip` |

示例:

```bash
NPM_CLI=/usr/local/bin/npm bash dep-audit/bin/audit.sh ./my-node-app
```

## 依赖

各生态按需,未安装则跳过:

- **npm** — Node.js 项目(`package.json`)
- **go** — Go 项目(`go.mod`)
- **flutter** — Flutter 项目(`pubspec.yaml`)
- **pip** — Python 项目(`requirements.txt`)

## 测试

```bash
bash dep-audit/tests/run.sh
# 用 stub 工具跑,不依赖真实网络或已安装的包管理器
```

## License

[MIT](../../LICENSE)
