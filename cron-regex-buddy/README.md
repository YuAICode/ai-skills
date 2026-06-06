# cron-regex-buddy

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/cron-regex-buddy)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

用中文解释或生成 cron 表达式与正则表达式,逐字段/逐组讲清含义并给出匹配示例。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r cron-regex-buddy ~/.claude/skills/
```

## 📖 用法

### 解释模式

把一个 cron 或正则表达式交给 Claude,让它逐字段 / 逐组用中文讲清楚:

```
/cron-regex-buddy 解释这个 cron:0 9 * * 1-5
/cron-regex-buddy 这个正则什么意思:[0-9]{3}-[0-9]{4}
```

### 生成模式

用中文描述需求,Claude 产出对应的 cron 或正则 + 解释 + 注意事项:

```
/cron-regex-buddy 帮我写个每周一凌晨 2:30 的 cron 表达式
/cron-regex-buddy 帮我写个匹配 11 位手机号的正则
```

### bin 校验脚本(独立使用)

```bash
# 校验 cron(5 或 6 段,粗校验字符)
bash cron-regex-buddy/bin/validate.sh cron "0 9 * * 1-5"
# exit 0 = 合法,exit 2 = 非法 + 中文提示

# 校验正则(POSIX ERE,用 grep -E 干跑)
bash cron-regex-buddy/bin/validate.sh regex "[0-9]{3}-[0-9]{4}"
# exit 0 = 合法,exit 2 = 非法 + 中文提示
```

## 🧪 测试

```bash
bash cron-regex-buddy/tests/run.sh
# 22 个断言:cron 合法/非法/字段不足/非法字符,regex 合法/未配对括号/量词无操作数
```

## 📄 License

[MIT](../LICENSE)
