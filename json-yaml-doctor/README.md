# json-yaml-doctor

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/json-yaml-doctor)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

校验 / 格式化 / 解释 JSON·YAML(·TOML),报错给中文定位。支持按扩展名自动识别类型,合法时可输出美化内容,非法时给出行列 + 中文错误说明。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r json-yaml-doctor ~/.claude/skills/
```

## 用法

跟 Claude 说**"校验这个 json / 检查 yaml / json-yaml-doctor"**,它会:
1. 跑 `bin/check.sh` 解析文件并输出结构化报告
2. 用中文解释报错原因(尾逗号、单引号、Tab 缩进、键重复等常见坑)
3. 给出修法——不自动修改原文件

也可单独跑脚本:

```bash
# 校验语法
bash json-yaml-doctor/bin/check.sh config.json
bash json-yaml-doctor/bin/check.sh values.yaml

# 校验 + 输出美化内容
bash json-yaml-doctor/bin/check.sh config.json --format

# 从 stdin 读(自动探测类型)
cat config.json | bash json-yaml-doctor/bin/check.sh -
```

### 环境变量

| 变量 | 说明 | 默认值 |
| ------------ | ---------------------- | ----------- |
| `PYTHON_BIN` | 覆盖 python 解释器路径 | `python3` |

示例:

```bash
PYTHON_BIN=/usr/bin/python3.11 bash json-yaml-doctor/bin/check.sh app.toml
```

### 退出码

| 退出码 | 含义 |
| ------ | ---- |
| `0` | 语法合法(或依赖缺失跳过) |
| `2` | 语法错误(已输出中文定位) |

## 依赖

| 格式 | 依赖 | 备注 |
| ---- | ---- | ---- |
| JSON | python3 标准库 | 始终可用 |
| YAML | python3 + pyyaml | 缺失时提示 `pip install pyyaml` 并跳过 |
| TOML | python3 3.11+ tomllib | 低版本提示并跳过 |

## 测试

```bash
bash json-yaml-doctor/tests/run.sh
# 造合法/非法样本文件,验证退出码与中文报错,不依赖网络
```

## License

[MIT](../LICENSE)
