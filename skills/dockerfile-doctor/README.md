# dockerfile-doctor

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/dockerfile-doctor)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

扫描 Dockerfile 的体积/安全/缓存/最佳实践问题,并给出中文修法建议。

## 安装

把目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
cp -r dockerfile-doctor ~/.claude/skills/
```

## 用法

### 直接调用脚本

```bash
# 扫描当前目录下的 Dockerfile
bash bin/check.sh

# 扫描指定路径
bash bin/check.sh /path/to/Dockerfile
```

退出码说明:
- `0` — 没有发现问题,Dockerfile 符合规范
- `2` — 发现一个或多个问题(含行号 + 中文说明)

### 在 Claude Code 中触发

告诉 Claude:
- "帮我检查 Dockerfile"
- "Dockerfile 有没有问题"
- "审查一下这个 Dockerfile"
- "/dockerfile-doctor"

Claude 会调用 `bin/check.sh`,并对每条问题给出:
1. 为什么这是问题
2. 如何修改
3. （可选）改写后的 Dockerfile 片段

### 检测规则

| 规则 | 说明 |
|------|------|
| `:latest` 或无 tag | 镜像版本不可复现 |
| 无非 root 用户 | 以 root 运行存在安全风险 |
| apt 未清理缓存 | 镜像体积增大 |
| `ADD` 用于本地文件 | 应优先使用 `COPY` |
| `COPY . .` 在依赖前 | 破坏构建层缓存 |
| 疑似密钥写入 `ENV`/`ARG` | 密钥泄露风险 |
| 缺少 `.dockerignore` | 可能把不必要的文件打进镜像 |
| 多条 `RUN` 未合并 | 增加镜像层数(弱提示) |

## 运行测试

```bash
bash tests/run.sh
```

## License

[MIT](../../LICENSE)
