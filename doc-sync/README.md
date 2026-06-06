# doc-sync

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/doc-sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

代码改动后,用 git+grep 扫出引用了改动文件的 Markdown 文档候选,再由 Claude 逐个研判、给出同步建议——不自动改文档,给你决定权。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r doc-sync ~/.claude/skills/
```

## 用法

跟 Claude 说**"检查文档同步 / 代码改了文档要更新吗 / 找过期文档"**,它会:

1. 跑 `bin/find-stale-docs.sh` 找出引用了本次改动文件的 Markdown 候选;
2. 逐个阅读候选文档 + 对应改动,判断是否真的过期;
3. 给出具体改动建议(哪行改成什么),等你确认后再动文件。

也可以单独跑扫描脚本:

```bash
bash doc-sync/bin/find-stale-docs.sh              # 自动探测基点
bash doc-sync/bin/find-stale-docs.sh origin/main  # 手动指定基点
bash doc-sync/bin/find-stale-docs.sh v1.2.0       # 与某 tag 对比
```

输出包含 `CHANGED_FILES`(改动文件)、`SEARCH_SCOPE`(扫描范围)、`STALE_DOCS`(候选文档 + 命中词)。

## 依赖

- **git + grep**:纯内置,零外部依赖。
- 在 git 仓库根或子目录下运行;非 git 目录会报错退出。

## 测试

```bash
bash doc-sync/tests/run.sh   # 临时 repo,造改动 + 文档引用,验证候选命中/不命中
```

## License

[MIT](../LICENSE)
