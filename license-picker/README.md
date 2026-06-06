# license-picker

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/license-picker)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

帮你挑一个合适的开源协议,并生成填好作者/年份的 `LICENSE`。

## 🚀 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r license-picker ~/.claude/skills/
```

## 📖 用法

跟 Claude 说**"帮我选个开源协议 / 加个 LICENSE"**,它会先问诉求(宽松?要专利条款?copyleft?)给推荐,再生成:

```bash
bash license-picker/bin/add-license.sh MIT "张三" 2026
bash license-picker/bin/add-license.sh BSD-3-Clause          # author 取 git 配置,year 取今年
```

- **内置可填充**:`MIT` `ISC` `BSD-2-Clause` `BSD-3-Clause` `Unlicense`
- **copyleft 指引**:`Apache-2.0` `GPL-3.0`(正文长且须逐字使用,脚本给官方链接)
- 已存在 `LICENSE` 不覆盖,除非加 `--force`

> ⚠️ 不构成法律意见;重要场景请咨询专业人士。

## 🧪 测试

```bash
bash tests/run.sh   # 生成/填充/防覆盖/未知 id/copyleft 指引
```

## 📄 License

[MIT](../LICENSE)
