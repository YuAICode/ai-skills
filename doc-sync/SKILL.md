---
name: doc-sync
description: 代码改动后找出可能过期的文档候选清单,辅助 Claude 判断是否需要同步更新。当用户说"检查文档同步 / 代码改了文档要更新吗 / 找过期文档 / doc-sync"时触发。
---

# doc-sync — 找过期文档候选

代码改了,文档跟上了吗?本 skill 用纯 git+grep 扫出**引用了本次改动文件的 Markdown 文档候选**,再由 Claude 逐个判断是否真的需要更新,最后给出具体改动建议。

## 何时触发

用户说:
- "检查文档同步 / doc-sync"
- "代码改了,文档要更新吗"
- "找找过期文档 / 有哪些文档需要同步"
- "这批改动会影响哪些文档"

## 工作流

### 1. 扫候选(确定性脚本)

```bash
bash <skill>/bin/find-stale-docs.sh [base]
# base 缺省:自动探测 origin/HEAD → origin/main → origin/master → main → master
# 例:bash <skill>/bin/find-stale-docs.sh origin/main
#     bash <skill>/bin/find-stale-docs.sh v1.2.0
```

输出:
- `BASE` — 对比基点
- `CHANGED_FILES` — 本次改动的文件列表
- `SEARCH_SCOPE` — 扫描的 Markdown 文档总数
- `STALE_DOCS` — 引用了改动文件的文档候选 + 命中关键词

### 2. Claude 逐个研判

对 `STALE_DOCS` 里的每个候选,阅读文档内容 + 对应改动,判断:
- 文档里的描述/示例/接口签名是否与代码改动有实质出入?
- 是轻微过时(命名/注释变动)还是需要重写?
- 是否有其他未被脚本命中但逻辑上应同步的文档?

若候选为空,也要告知用户"当前文档没有引用这些改动文件,建议人工复核主要入口文档"。

### 3. 给出建议改动

- 对需要更新的文档,给出具体的**补丁建议**(哪行改成什么)。
- **不要自动改文档**。展示建议后等用户确认,用户同意后才 Edit/Write。
- 建议按"影响大→小"排序,帮用户决定优先级。

## 边界

- 脚本只用 basename(去扩展名)和完整路径做关键词匹配——候选会有**误报**(文档引用同名词但逻辑无关)和**漏报**(文档用别名/跨语言描述),Claude 的研判环节负责过滤。
- 只扫仓库内 git 追踪的 `*.md` 文件;`.rst`/`.adoc`/wiki 等格式不在范围。
- 只读 git diff + 文档文件,**不改任何代码或文档**,除非用户明确同意。
- 不联网、不依赖 CI。
