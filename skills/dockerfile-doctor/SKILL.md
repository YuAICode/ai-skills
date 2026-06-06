---
name: dockerfile-doctor
description: 扫描 Dockerfile 的体积/安全/缓存/最佳实践问题并给出中文修法。当用户说"帮我检查 Dockerfile / Dockerfile 有没有问题 / 审查 Dockerfile / dockerfile-doctor"时触发。
---

# dockerfile-doctor

扫描 Dockerfile 的常见反模式——体积膨胀、安全隐患、缓存破坏、密钥泄露——给出带行号的中文问题报告,并帮用户逐条修复。

## 何时触发

- "帮我检查 Dockerfile"
- "Dockerfile 有没有问题 / 有什么问题"
- "审查一下这个 Dockerfile"
- "帮我优化 Dockerfile"
- "Dockerfile 最佳实践检查"
- "/dockerfile-doctor"

## 工作流

### 第一步:运行检查脚本

```bash
bash <skill>/bin/check.sh [Dockerfile路径]
# 默认扫描 ./Dockerfile
# exit 0 = 无问题;exit 2 = 有问题(stdout 含行号 + 中文说明)
```

### 第二步:解读每条问题

对 `check.sh` 输出的每条问题,用中文讲清:
1. **为什么是问题** — 体积/安全/可复现性/缓存效率等维度说明
2. **怎么改** — 给出修改建议,必要时提供改写后的 Dockerfile 片段

示例问题与解读:

| 问题 | 为什么 | 修法 |
|------|--------|------|
| `:latest` 或无 tag | 镜像不可复现,CI 结果可能随时改变 | 指定确定版本如 `FROM node:20.11-alpine` |
| 无 `USER` 非 root | 容器内以 root 运行,漏洞利用代价低 | 末尾加 `USER nobody` 或创建专用用户 |
| apt 未清理 `/var/lib/apt/lists/*` | 每层缓存留在镜像里,体积膨胀 | `RUN apt-get update && apt-get install -y --no-install-recommends xxx && rm -rf /var/lib/apt/lists/*` |
| `ADD` 用于本地文件 | `ADD` 有解压/URL 拉取副作用,语义不明确 | 纯本地拷贝一律用 `COPY` |
| `COPY . .` 在依赖安装前 | 源码任意改动都会让 npm/pip/go 等安装层失效 | 先 `COPY package.json ./` 安装依赖,再 `COPY . .` |
| `ENV`/`ARG` 含密钥 | 密钥固化进镜像层,`docker history` 可见 | 用 `--secret` (BuildKit) 或运行时注入环境变量 |
| 缺 `.dockerignore` | `.git`/`node_modules` 等可能被打进镜像 | 在同目录建 `.dockerignore`,排除不需要的文件 |
| 多条分散 `RUN` | 增加镜像层数,体积偏大 | 相关命令合并为单条 `RUN`,用 `&&` 和 `\` 连接 |

### 第三步:提供修改后片段(可选)

如果用户希望,可以输出完整的改写建议片段。遵守两条硬规则:
- **只读 + 给建议,不自动覆盖文件**
- **疑似密钥提醒打码**:输出时把密钥值替换为 `<REDACTED>`,提示用户自行处理

## 边界

- 纯静态文本扫描,不执行 `docker build`
- 不检查基础镜像是否真实存在于 Registry
- 多条 `RUN` 合并是弱提示(体积收益小时可忽略)
- 不自动修改文件,所有改动由用户决定
