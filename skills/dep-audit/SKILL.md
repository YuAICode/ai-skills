---
name: dep-audit
description: 扫依赖清单,报过期/有风险的依赖,给中文升级摘要。当用户说"检查依赖 / 依赖过期了吗 / dep-audit / 扫依赖 / 有没有过期包 / 依赖健康检查"时触发。
---

# dep-audit — 依赖过期检查 + 中文摘要

扫项目的依赖清单,列出哪些包落后于最新版,把原始 outdated 输出整理成中文摘要,给出升级建议——只读,不自动改清单。

## 何时触发

用户说"检查依赖 / 依赖过期了吗 / dep-audit / 扫依赖 / 有没有过期包 / 依赖健康检查"时触发。

## 工作流

### 1. 跑扫描脚本(只读,不升级)

```bash
bash <skill>/bin/audit.sh [项目目录]
# 项目目录默认为当前目录
# 例:bash dep-audit/bin/audit.sh /path/to/my-project
```

脚本自动探测项目里存在哪些清单文件,对每个可用生态跑只读的过期检查,输出原始结果:

| 清单文件 | 工具命令 | 环境变量覆盖 |
| -------------- | ----------------------------- | ------------ |
| `package.json` | `npm outdated` | `NPM_CLI` |
| `go.mod` | `go list -m -u all` | `GO_CLI` |
| `pubspec.yaml` | `flutter pub outdated` | `FLUTTER_CLI` |
| `requirements.txt` | `pip list --outdated` | `PIP_CLI` |

- 工具未安装 → 打印"跳过 <生态>(未装 <tool>)"并继续,不崩退。
- 没有任何清单 → 提示"未发现依赖清单"并退出 0。

### 2. Claude 整理中文摘要

拿到脚本的原始输出后,按以下结构整理:

```markdown
## <项目目录> 依赖审计报告

### npm / Go / Flutter / Python(各生态分节)

#### 可安全升级(patch / minor)
- `包名` current → latest — 简短说明(如有已知漏洞请标注)

#### 需谨慎的大版本升级(major)
- `包名` current → latest — 说明破坏性风险或 API 变更要点

#### 已知风险提示
- 若 npm 输出含 `WARN` / `deprecated`,或版本严重落后,在此单列说明

### 升级建议
1. 优先升级有已知安全漏洞的包
2. patch/minor 版本可批量升;major 版本建议阅读 changelog 后单独测试
3. 升级前做好版本快照(lockfile / go.sum)
```

### 3. 纯只读原则

- 脚本和 Claude 均**不修改**任何清单文件(`package.json` / `go.mod` / `pubspec.yaml` / `requirements.txt`)。
- 不自动执行 `npm install` / `go get` / `flutter pub upgrade` 等升级命令。
- 如用户决定升级,再另行执行;需要帮助时可再开一轮对话。

## 边界

- 依赖对应工具已安装;未安装则跳过该生态并提示。
- npm outdated 退出码 1 属正常(有过期包时);脚本已处理,不视为失败。
- go list -m -u all 输出需联网(访问 proxy.golang.org);离线环境可能为空。
- 不扫传递依赖的安全漏洞(如需深度安全审计,可配合 `npm audit` / `govulncheck` 另跑)。
