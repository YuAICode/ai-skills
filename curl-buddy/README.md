# curl-buddy

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/curl-buddy)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

构造或解释 curl/HTTP 请求命令——逐项拆解方法、URL、headers、body、认证与关键 flag，并标注安全风险。全程中文；绝不真发请求。

## 安装

把目录拷进 Claude Code 的 skills 目录，重启后即可触发：

```bash
# 全局（所有项目可用）
cp -r curl-buddy ~/.claude/skills/

# 或 项目级（只在当前项目生效）
cp -r curl-buddy .claude/skills/
```

## 用法

### 解释模式

把一条 curl 命令交给 Claude，逐项用中文讲清楚它在做什么、有没有风险：

```
/curl-buddy 帮我解释这条 curl：
curl -X POST https://api.example.com/v1/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"foo"}' \
  -k
```

Claude 会输出：

```
解析结果：
- 方法：POST
- URL：https://api.example.com/v1/items
- 请求头：
  - Authorization: Bearer $TOKEN → Bearer Token 认证
  - Content-Type: application/json → 请求体为 JSON 格式
- 请求体：{"name":"foo"} → JSON，包含字段 name=foo
- flag：-k（跳过 TLS 证书校验）

含义：向 example.com 的 /v1/items 发 POST 请求，新建名为 "foo" 的资源。

风险提示：
- -k 跳过证书校验，存在中间人攻击风险，生产环境禁用。
- Bearer Token 若硬编码在命令中会留在 shell history，建议改用 export TOKEN=<your-token>。
```

### 构造模式

用中文描述需求，Claude 产出规范 curl 命令 + 逐项说明 + 注意事项：

```
/curl-buddy 帮我构造一个 curl 请求：
向 https://api.example.com/users 发 GET，带 Bearer token，接收 JSON 响应。
```

Claude 会产出：

```
生成命令：
  curl -X GET https://api.example.com/users \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json"

注意事项：
- 使用前请先 export TOKEN=<你的 token>，不要把真实 token 写进命令。
```

### 响应解读模式

粘贴 curl 返回的状态码、响应头或响应体，Claude 基于**真实输出**解读——不臆造：

```
/curl-buddy 这个响应什么意思：
HTTP/2 401
www-authenticate: Bearer realm="example", error="invalid_token"
{"message":"token expired"}
```

### bin 脚本（独立使用）

```bash
# 把 curl 命令拆成结构化字段（纯解析，不发请求）
bash curl-buddy/bin/parse-curl.sh 'curl -X POST https://example.com/api \
  -H "Content-Type: application/json" \
  -d '"'"'{"key":"val"}'"'"''

# 输出：
# METHOD=POST
# URL=https://example.com/api
# HEADERS=Content-Type: application/json
# DATA={"key":"val"}
# FLAGS=
```

exit 0 = 解析成功；exit 2 = 无效 curl 命令；exit 1 = 用法错误。

## 测试

```bash
bash curl-buddy/tests/run.sh
# 37 个断言：METHOD/URL/HEADERS/DATA/FLAGS 字段解析、无效命令拦截、
# 多行续行符、脚本不联网验证
```

## 触发词

- `/curl-buddy`
- "帮我解释这条 curl"
- "这个 curl 是什么意思"
- "帮我构造一个 curl 请求"
- "怎么用 curl 调这个接口"
- "这条 curl 安全吗"

## 硬规则摘要

- 绝不真发请求（bin 脚本纯解析，Claude 只解释/构造）
- 命令含 token/密码时必须提醒改用环境变量
- `-k` 等风险 flag 必须标注
- 响应解读基于用户粘贴的真实输出，不编造

## License

[MIT](../LICENSE)
