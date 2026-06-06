# lambda-logs-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/lambda-logs-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

拉 AWS Lambda 的 CloudWatch 最近报错,按频次聚类并给中文根因摘要——不用再手翻一屏屏日志。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r lambda-logs-zh ~/.claude/skills/
```

## 📖 用法

跟 Claude 说**"看下 my-func 的 lambda 报错"**,它会跑取日志脚本 → 按错误本质聚类 → 给"每类 ×次数 + 中文根因 + 建议"。

也能单独跑取日志脚本:

```bash
bash lambda-logs-zh/bin/fetch-errors.sh my-func 6h ap-southeast-1
bash lambda-logs-zh/bin/fetch-errors.sh --group /aws/lambda/my-func 24h
```

窗口支持 `1h`/`6h`/`24h`/`7d`(缺省 1h)。

## ⚙️ 依赖

- **aws CLI + 已配置凭据/region**(缺失时脚本明确报错)
- 默认日志组 `/aws/lambda/<函数名>`;非常规命名用 `--group` 直传

## 🧪 测试

```bash
bash tests/run.sh   # 用 aws stub 验证参数拼装,不依赖真实 AWS
```

## 📄 License

[MIT](../../LICENSE)
