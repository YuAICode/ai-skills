# commit-guard-zh — 设计 (Spec)

> 状态:V1,已与用户对齐(2026-06-06)
> 归属:`YuAICode/ai-skills` 下新 skill 子目录

## 目标

提交/推送前在本地把关 + 帮写中文 commit。合并自原计划的 4 个独立 skill:
secret-scan、gorm-mysql-check、push-guard(由 lambda-deploy-guard 通用化而来)、commit-zh。

全部**通用**(不含任何 OneClub 专属逻辑),可公开分享;项目相关阈值走 config。

## 架构:脚本核 + skill 编排

确定性检查用纯 bash 写成独立脚本,**一份代码两用**——既被 skill 工作流调用,也能装成 git hook。
只有"生成中文 commit"需要 LLM,故仅存在于 skill 工作流。

```
commit-guard-zh/
├── SKILL.md              # Claude 工作流(说“提交/要 push 了”时触发)
├── README.md             # 安装/用法 + 徽章
├── config.example.sh     # 可调项;复制为 .commit-guard.sh 放目标 repo 根
├── bin/
│   ├── secret-scan.sh        # 扫 staged diff 的密钥/凭据
│   ├── gorm-mysql-check.sh   # 扫 staged .go 的 GORM×MySQL 非法写法(默认关)
│   └── push-guard.sh         # 主分支保护 + env 文件防提交
├── hooks/{pre-commit,pre-push}   # 薄包装,调 bin/
├── install.sh / uninstall.sh     # 装/卸 git hook 到目标 repo(sentinel 可逆)
└── tests/run.sh                  # 正例/反例验证拦截与放行
```

## 各检查行为

| 检查 | 实现 | 触发点 | 默认 |
|---|---|---|---|
| secret-scan | bash+grep | pre-commit / skill | 开 |
| gorm-mysql-check | bash+grep(仅 `*.go`) | pre-commit / skill | **关**(config 开) |
| push-guard | bash | pre-push / skill | 开 |
| markdownlint(扫 staged .md;后续增补) | bash(调 markdownlint-cli) | pre-commit / skill | **关**(config 开,未装自动跳过) |
| commit-zh(中文 commit) | Claude | 仅 skill | 开 |

- **secret-scan**:扫 `git diff --cached`。命中 API key / 私钥块(`BEGIN ... PRIVATE KEY`)/ `.p8` / 看似 firebase service-account JSON / 高熵 `password=`/`token=` 赋值 → `exit 2` 拦截。支持 config 白名单(正则/路径)。宁可误报也要拦。
- **gorm-mysql-check**:扫 staged `*.go`,命中 GORM tag 里 TEXT/BLOB/JSON 列带 `default:`(MySQL Error 1101)→ `exit 2` 并给修法(去掉 default 或改列类型)。
- **push-guard**:pre-push 时,若推到 `main`/`master`(可 config)→ 提示需确认(hook 模式打印警告+要求 `COMMIT_GUARD_CONFIRM=1`;skill 模式由 Claude 确认本回合是否授权);并检查本次推送提交里没混进 `.env`/密钥文件。
- **commit-zh**:Claude 读 staged diff,生成中文 conventional commit(`fix:`/`feat:` 前缀),代码/专有名词留英文。仅在前三项全过后执行。

## 退出码约定

- `exit 0` 静默 = 通过
- `exit 0` + stderr = 警告(不拦)
- `exit 2` + stderr = 拦截(git hook 会中止操作)

## skill 工作流(SKILL.md)

触发:用户说“准备提交 / 帮我 commit / 要 push 了”。
1. 跑 secret-scan、(若启用)gorm-mysql-check;有 `exit 2` → 用中文讲清问题+修法,停下等用户。
2. 全过 → 读 diff 生成中文 commit message,展示给用户确认后 `git commit`。
3. 若要 push 到保护分支 → 先确认本回合是否已获授权(对应用户“别直接 push main”铁律),再 push。

## 错误处理

- 脚本零外部依赖(纯 bash + grep + git);解析异常一律 `exit 0` 不误伤工具链。
- 找不到 config → 用内置默认值。
- secret 命中从严(可白名单豁免)。

## 测试

`tests/run.sh`:对每个 bin 脚本喂正例(应放行)+ 反例(应 `exit 2`),断言退出码。无网络、可离线跑。

## 非目标 (YAGNI)

- 不做任何 OneClub 专属检查(RDS 池 / reservedConcurrency / 特定仓库名)。
- 不联网、不扫历史(只看本次 staged / 本次 push 的提交)。
- 不替代 CI——这是本地前移的快速护栏。
