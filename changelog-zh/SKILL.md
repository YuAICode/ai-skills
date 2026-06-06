---
name: changelog-zh
description: 从 conventional commits 生成中文 CHANGELOG / release notes。当用户说"生成 changelog / 出个更新日志 / 写 release notes / 这版改了啥"时触发。脚本按提交类型归类,Claude 润色成中文小节并可 prepend 到 CHANGELOG.md。
---

# changelog-zh — 中文更新日志生成

把一串 conventional commits 收敛成人话版中文更新日志。

## 何时触发

用户说"生成 changelog / 出个更新日志 / 写 release notes / 这版改了啥"。

## 用法

1. 归类提交(确定性脚本):
   ```bash
   bash <skill>/bin/collect-commits.sh [from] [to]
   # from 缺省=最近一个 tag(无 tag 则从根);to 缺省=HEAD
   # 例:bash <skill>/bin/collect-commits.sh v1.2.0 HEAD
   ```
   输出 RANGE + 按类型分组(`### feat (×N)` / `### fix` / … / `### other`),已去掉类型前缀。
2. 确认**版本号 + 日期**(问用户,或从 tag/package 推断)。
3. 把分组**润色成中文小节**(见模板),合并琐碎项、丢掉纯内部噪音(如 `chore: 改 typo` 可省)。
4. **prepend 到 `CHANGELOG.md`** 顶部(保留历史);没有就新建。展示给用户确认。

## 类型 → 中文小节映射

| conventional | 中文小节 |
|---|---|
| feat | ✨ 新功能 |
| fix | 🐛 修复 |
| perf | ⚡ 性能 |
| refactor | ♻️ 重构 |
| docs | 📝 文档 |
| test | ✅ 测试 |
| build / ci | 🔧 构建/CI |
| 含 `!` 或 BREAKING | ⚠️ 破坏性变更(单独置顶) |
| other | 其它 |

## 模板

```markdown
## [<版本>] - <YYYY-MM-DD>

### ⚠️ 破坏性变更
- <如有,置顶并说明迁移>

### ✨ 新功能
- <条目>

### 🐛 修复
- <条目>
```

## 硬规则

- **破坏性变更**(commit 带 `!` 或正文有 BREAKING)必须单独置顶。
- 面向**读者**写,不是堆 commit:同类合并、删内部噪音、把缩写展开成人话。
- 不臆造没发生的改动;`other` 里的非规范提交按内容归到合适小节或如实列出。
- 只读 git + 写 CHANGELOG.md,不打 tag、不发布。

## 边界

- 依赖 conventional commits;提交不规范时归类质量下降(other 会变多)。
- 版本号/打 tag/发 release 由用户决定,本 skill 不碰。
