# commit-guard-zh 配置示例
# 用法:复制为目标 repo 根目录的 .commit-guard.sh,按需改值。
# 这是被 source 的 shell 片段,只放变量赋值。

# 受保护分支(空格分隔),推送时需 COMMIT_GUARD_CONFIRM=1 确认
BRANCH_PROTECT="main master"

# 是否启用 GORM × MySQL 检查(仅 Go + GORM 项目有意义,默认关)
ENABLE_GORM_CHECK=0

# 是否启用 markdownlint 检查暂存的 .md(需装 markdownlint-cli,默认关;未装则自动跳过)
ENABLE_MD_LINT=0

# secret-scan 误报白名单(extended regex,匹配到的命中行会被豁免)
# 例:豁免测试夹具目录 + 文档里的示例 key
# SECRET_WHITELIST='testdata/|docs/|EXAMPLE_KEY'
SECRET_WHITELIST=""
