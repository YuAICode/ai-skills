---
name: pr-desc-zh
description: 从 git diff / commits 生成中文 PR 描述(动机、改动点、测试、影响面)。当用户说"生成 PR 描述 / 写个 PR / 提 MR / 写 PR 说明"时触发。先用脚本采集提交与改动素材,再产出结构化中文描述,可选直接 gh pr create。
---

# pr-desc-zh — 中文 PR 描述生成

把"一堆 commit + diff"变成 reviewer 看得懂、三个月后还能回溯的中文 PR 描述。

## 何时触发

用户说"写个 PR / 生成 PR 描述 / 提 MR / 帮我写 PR 说明"。

## 用法

1. 采集素材(确定性脚本,在目标分支上跑):
   ```bash
   bash <skill>/bin/collect.sh [base分支]
   ```
   不传 base 会自动探测默认分支(origin/HEAD → origin/main → main…)。输出 BASE / COMMITS / FILES / DIFFSTAT。
2. 读这些素材 +(必要时)`git diff <base>..HEAD` 细节,按下面模板产出中文描述。
3. 展示给用户确认。要的话用 `gh pr create --title "<标题>" --body "<正文>"` 直接开 PR。

## 描述模板

```markdown
## 这个 PR 做了什么
<一两句话点题,标题用 conventional 前缀 + 中文>

## 动机 / 背景
<为什么改;关联的需求/issue>

## 改动点
- <按模块分条;每条说清"改了什么、为什么这么改">

## 影响面
- <受影响的端/模块/接口;有无破坏性变更;迁移注意>

## 测试
- [ ] <怎么验证的;跑了哪些测试>

## 备注 / 待确认
- <reviewer 需要重点看的 / 还没定的>
```

## 硬规则

- 标题用 conventional 前缀(`feat:`/`fix:`/`refactor:`…)+ 中文描述;代码标识符、API、库名保持英文。
- **不臆造**:测试项、影响面拿不准就标"待确认",别编。
- 破坏性变更、DB 迁移、共享契约(如 swagger)改动必须在「影响面」点出。
- 描述基于真实 diff;commit 信息不足时看 diff 补全,而不是猜。

## 边界

- 只读 git,不自动推送/合并;`gh pr create` 仅在用户同意后执行。
- base 探测不到时要求用户显式指定。
