# env-doctor

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/env-doctor)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

项目跑前环境配置体检——检测缺失的 .env、对比 .env.example 列出未配置的 key 和空值 key,提前报警别等运行时炸。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r env-doctor ~/.claude/skills/
```

## 📖 用法

跟 Claude 说**"体检环境 / 检查 env / .env 缺了什么"**,它会:

1. 跑 `bin/check-env.sh` 检测 .env.example(或 .env.sample / .env.template)与 .env 的差异;
2. 用中文列出缺失的 key、值为空的 key;
3. 给出补全建议,以及"程序读不到环境变量"的常见坑提醒。

也可以单独跑体检脚本:

```bash
bash env-doctor/bin/check-env.sh              # 当前目录
bash env-doctor/bin/check-env.sh ~/my-project  # 指定项目目录
```

### 退出码

| 退出码 | 含义 |
|--------|------|
| `0` | 配置完整(或无模板可对比) |
| `0` | 有模板但 .env 缺失(给出告警和建议) |
| `2` | 有缺失 key 或空值 key,需补全 |
| `1` | 脚本出错(目录不存在等) |

### 常见坑

> Go / Java / C 等项目不会自动加载 .env。跑程序前需手动导入:
> ```bash
> set -a; source .env; set +a
> ```

## 🧪 测试

```bash
bash tests/run.sh   # 离线,临时目录造 .env 对,断言缺失/空值/完整/变体名各场景
```

## 📄 License

[MIT](../LICENSE)
