# standup-zh

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/standup-zh)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

从 git 提交生成中文日报或周报。中国团队刚需:把"一堆 commit"收敛成站会能直接念的人话。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r standup-zh ~/.claude/skills/
```

## 用法

在项目目录里跟 Claude 说**"写日报 / 写周报 / 今天做了什么 / standup"**,Claude 会:

1. 跑 `bin/collect-activity.sh [since] [author]` 采集提交与改动统计;
2. 按模板生成**中文日报**或**中文周报**。

也可以单独跑采集脚本查看素材:

```bash
# 日报(默认 1 day ago,当前 git user.email)
bash standup-zh/bin/collect-activity.sh

# 周报
bash standup-zh/bin/collect-activity.sh "1 week ago"

# 指定作者与起始时间
bash standup-zh/bin/collect-activity.sh "2024-06-01" "alice@example.com"
```

输出段落:

| 段落 | 内容 |
|------|------|
| `RANGE` | 时间范围 |
| `AUTHOR` | 作者邮箱 |
| `COMMITS` | 提交列表(hash/日期/subject) |
| `STATS` | 汇总改动文件数与增删行数 |

## 测试

```bash
bash standup-zh/tests/run.sh
```

临时 repo 造提交 → 验证区间过滤、author 过滤、RANGE/AUTHOR 头输出正确。

## 许可证

[MIT](../../LICENSE)
