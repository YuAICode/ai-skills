# test-gen-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/test-gen-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

给指定函数或文件生成测试用例,配合 TDD 习惯——覆盖正常路径、边界值、错误路径,不凑覆盖率。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r test-gen-zh ~/.claude/skills/
```

## 用法

跟 Claude 说 **"帮我给这个函数写测试"** 或 **"/test-gen-zh \<文件路径\>"**,它会:

1. 自动探测测试框架(Go / Rust / Flutter / Jest / Vitest / pytest)
2. 读实现文件,理解行为
3. 参照项目已有测试风格
4. 生成覆盖正常/边界/错误路径的完整测试代码

也可单独跑框架探测脚本:

```bash
bash test-gen-zh/bin/detect-framework.sh [项目目录]
# 输出:go test | jest | vitest | flutter test | pytest | cargo test | unknown
# 默认当前目录
```

### 支持的框架

| 框架 | 识别依据 |
|------|---------|
| `go test` | `go.mod` |
| `cargo test` | `Cargo.toml` |
| `flutter test` | `pubspec.yaml` |
| `vitest` | `package.json` 含 `"vitest"` |
| `jest` | `package.json` 含 `"jest"` |
| `pytest` | `requirements*.txt` / `pyproject.toml` / `setup.cfg` / `setup.py` 含 `pytest` |
| `unknown` | 识别不了,Claude 会询问用户 |

## 测试

```bash
bash test-gen-zh/tests/run.sh
# 造临时项目目录,验证 detect-framework.sh 各框架识别正确
```

## License

[MIT](../../LICENSE)
