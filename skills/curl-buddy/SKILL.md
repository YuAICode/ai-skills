---
name: curl-buddy
description: 构造或解释 curl/HTTP 请求命令,逐项拆解方法、URL、headers、body、认证与关键 flag,并提示安全风险。触发词:'/curl-buddy'、'帮我解释这条 curl'、'帮我构造一个 curl 请求'、'这个 curl 是什么意思'、'怎么用 curl 调这个接口'。Use when the user wants to explain or build a curl / HTTP request command in Chinese.
---

# curl-buddy — curl / HTTP 请求中文向导

把看不懂的 curl 命令逐项讲清楚,或者把中文需求翻译成规范 curl 命令。
全程中文;curl 命令与 HTTP 原文保持原样;**绝不真发请求**。

## 何时触发

用户说：
- `/curl-buddy`
- "帮我解释这条 curl：`curl -X POST …`"
- "这个 curl 是什么意思"
- "帮我构造一个 curl 请求"
- "怎么用 curl 调这个接口"
- "帮我把这段描述翻成 curl"
- "这条 curl 安全吗"

## 两种工作模式

---

### 模式 A：解释模式

用户给出一条 curl 命令 → 逐项拆解,中文说明每个部分在做什么以及潜在风险。

**流程：**

1. 识别命令是否以 `curl` 开头;若不是则提示用户确认格式。
2. **先用 `bin/parse-curl.sh` 提取结构化字段**：
   ```bash
   bash <skill>/bin/parse-curl.sh "<curl 命令>"
   ```
   脚本输出 `METHOD`、`URL`、`HEADERS`、`DATA`、`FLAGS` 等字段,作为解释的骨架。
3. 逐项中文解释以下维度（有则解释，无则省略）：

   | 维度 | 关键 flag / 含义 |
   |------|-----------------|
   | **请求方法** | `-X`/`--request`；缺省默认 GET（有 `-d` 时自动 POST）|
   | **目标 URL** | 协议、域名、路径、查询参数 |
   | **请求头** | `-H`/`--header`；逐条说明用途（Content-Type / Authorization / Cookie 等）|
   | **请求体** | `-d`/`--data`/`--data-raw`/`--data-binary`/`--json`；格式与编码 |
   | **认证** | `-u`/`--user`（Basic Auth）；Bearer Token 在 `-H Authorization:…` |
   | **关键 flag** | 见下方"常用 flag 解释表" |
   | **输出/存储** | `-o`/`-O`/`-s`/`-v`/`-i` |

4. **风险提示**（有则列出）：
   - `-k`/`--insecure`：跳过 TLS/SSL 证书校验，中间人攻击风险，**生产环境禁用**。
   - `-u user:pass` 或 `-H "Authorization: Bearer <token>"` 裸写在命令行：会留在 shell history，建议改用环境变量（见"敏感信息处理"）。
   - `--data-raw` + 未编码 `&`/`=`：可能导致参数截断。
   - 重定向 `-L`：自动跟随 3xx，需确认目标安全。
   - `--max-time` / `--retry` 缺失：无超时/无重试，生产使用时应补充。

**常用 flag 解释表：**

| flag | 含义 |
|------|------|
| `-X METHOD` / `--request METHOD` | 指定 HTTP 方法（GET/POST/PUT/PATCH/DELETE 等） |
| `-H "K: V"` / `--header "K: V"` | 添加请求头；可多次使用 |
| `-d '…'` / `--data '…'` | 发送请求体（application/x-www-form-urlencoded 默认编码） |
| `--data-raw '…'` | 同 `-d` 但不读文件前缀 `@` |
| `--data-binary '…'` | 二进制体，不转换换行 |
| `--json '…'` | 发送 JSON 体（curl 7.82+，自动加 Content-Type: application/json） |
| `-u user:pass` | Basic Auth（Base64 编码，不加密） |
| `-L` / `--location` | 自动跟随 3xx 重定向 |
| `-k` / `--insecure` | 跳过证书校验（不安全，生产禁用） |
| `-o <file>` | 保存响应到文件 |
| `-O` | 以 URL 末段文件名保存 |
| `-s` / `--silent` | 静默模式，不显示进度/错误 |
| `-v` / `--verbose` | 显示详细请求/响应头（调试用） |
| `-i` / `--include` | 输出包含响应头 |
| `-I` / `--head` | 只发 HEAD 请求 |
| `--max-time <s>` | 超时秒数 |
| `--retry <n>` | 失败重试次数 |
| `-F "k=v"` / `--form "k=v"` | multipart/form-data 表单字段 |
| `--compressed` | 接受压缩响应（Accept-Encoding: gzip 等） |
| `-b "k=v"` / `--cookie "k=v"` | 发送 Cookie |
| `-c <file>` / `--cookie-jar <file>` | 保存 Set-Cookie 到文件 |
| `--proxy <url>` / `-x <url>` | 使用代理 |

**输出格式（解释模式）：**

```
命令：curl -X POST https://api.example.com/v1/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"foo"}'

解析结果：
- 方法：POST
- URL：https://api.example.com/v1/items
- 请求头：
  - Authorization: Bearer $TOKEN → Bearer Token 认证，服务端校验 token 有效性
  - Content-Type: application/json → 告知服务端请求体是 JSON 格式
- 请求体：{"name":"foo"} → JSON 格式，包含字段 name=foo
- 无特殊 flag

含义：向 example.com 的 /v1/items 接口发送一条 POST 请求，携带 Bearer Token 认证，新建名为 "foo" 的资源。

风险提示：
- Authorization 头中若直接硬编码真实 token，会留在 shell history；建议用 export TOKEN=<your-token> 后再执行命令。
```

---

### 模式 B：构造模式

用户用中文描述 HTTP 请求需求 → 产出规范 curl 命令 + 逐项说明 + 注意事项。

**流程：**

1. 如果需求不明确，先追问以下关键信息（缺哪个问哪个）：
   - 目标 URL / 接口地址
   - HTTP 方法（GET / POST / PUT / PATCH / DELETE 等）
   - 请求头（Content-Type、Authorization、自定义头等）
   - 请求体格式与内容（JSON / form-data / raw / 文件上传等）
   - 认证方式（无 / Basic / Bearer Token / API Key / Cookie 等）
   - 特殊要求（跟随重定向、忽略证书、超时、保存到文件等）

2. 生成格式规范的 curl 命令（多行用 `\` 续行，便于阅读）。

3. 按模式 A 的输出格式逐项解释生成结果。

4. 列出相关注意事项（从下方清单中挑取相关项）：

**构造注意事项清单（按需挑选）：**

- **敏感信息处理**：token / 密码不要硬编码在命令里；改用环境变量后引用 `$VAR_NAME`，并在 `.env` 或密钥管理器中存储。
- **Content-Type 与 body 格式匹配**：`application/json` + JSON body；`application/x-www-form-urlencoded` + `key=val&key2=val2`；`multipart/form-data` 用 `-F`。
- **Shell 转义**：JSON body 内有单引号时，使用 `$'…'` 或双引号 + `\"`；Windows cmd 下引号规则不同。
- **-k 生产禁用**：仅在本地调试自签证书时使用，正式环境必须移除。
- **-L 跟随重定向**：若不确定重定向目标，先不加 `-L` 观察 Location 响应头。
- **超时与重试**：生产脚本建议加 `--max-time 30 --retry 3 --retry-delay 2`。
- **响应检查**：可加 `-w "\n状态码: %{http_code}\n"` 输出状态码；`-s -o /dev/null -w "%{http_code}"` 只看状态码。
- **URL 编码**：查询参数含特殊字符时，用 `--data-urlencode` 或手动 percent-encode。
- **文件上传**：用 `-F "file=@/path/to/file"` 发 multipart；二进制数据用 `--data-binary @file`。

**输出格式（构造模式）：**

```
需求：向 https://api.example.com/users 发 GET 请求，带 Bearer token，返回 JSON。

生成命令：
  curl -X GET https://api.example.com/users \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json"

逐项说明：
- 方法：GET（读取资源，无请求体）
- URL：https://api.example.com/users
- Authorization: Bearer $TOKEN → Bearer Token 认证；$TOKEN 从环境变量读取
- Accept: application/json → 告知服务端期望返回 JSON 格式

注意事项：
- 使用前请先 export TOKEN=<你的 token>，不要把真实 token 写进命令。
- 如果服务端返回 401，检查 token 是否过期或格式是否需要前缀（如 Bearer 空格后跟值）。
```

---

### 模式 C：响应解读模式

用户粘贴了 curl 的真实返回内容（响应体 / 状态码 / 响应头）并问"这是什么意思" → 基于粘贴内容解读，不臆造。

**流程：**

1. 识别用户粘贴的是：HTTP 状态码 / 响应头 / JSON 响应体 / curl 错误信息。
2. 逐项解读：
   - **状态码**：含义（2xx 成功 / 3xx 重定向 / 4xx 客户端错误 / 5xx 服务端错误）+ 常见原因。
   - **响应头**：Content-Type、Cache-Control、Location、WWW-Authenticate、Retry-After 等关键头的含义。
   - **响应体**：若是 JSON，拆解关键字段；若是 HTML 错误页，提取关键错误信息。
   - **curl 错误码**：如 `(6) Could not resolve host`、`(60) SSL certificate problem` 等，给出中文原因和修复建议。
3. **严格基于用户提供的真实输出**，不臆造未出现的字段或数值。
4. 若信息不足无法判断根因，明确追问（如：完整响应头、请求体、服务端日志）。

**常见 curl exit code：**

| exit code | 含义 | 常见原因 |
|-----------|------|----------|
| 6 | Could not resolve host | DNS 解析失败，检查域名拼写或网络 |
| 7 | Failed to connect | 连接被拒绝，服务未启动或端口错误 |
| 28 | Operation timed out | 超时，检查 --max-time 或网络延迟 |
| 35 | SSL connect error | TLS 握手失败，检查证书或协议版本 |
| 52 | Empty reply from server | 服务端无响应，可能连接被关闭 |
| 56 | Recv failure | 接收数据时连接断开 |
| 60 | SSL certificate problem | 证书验证失败（自签证书时加 -k 临时绕过，生产环境需修复证书） |

---

## bin 脚本

```bash
# 把 curl 命令拆成结构化字段(不执行请求,纯解析)
bash <skill>/bin/parse-curl.sh "<curl 命令>"
```

输出格式：
```
METHOD=GET
URL=https://example.com/api
HEADERS=Authorization: Bearer $TOKEN | Content-Type: application/json
DATA={"key":"value"}
FLAGS=-L -s
```

exit 0 = 解析成功；exit 2 = 输入不是有效 curl 命令；exit 1 = 用法错误。

---

## 硬规则

1. **绝不真发请求**：只做解析、解释、构造；不执行 curl 或任何网络请求。
2. **不臆造响应**：响应解读严格基于用户粘贴的真实输出，没有的内容不编造。
3. **敏感信息必提示**：命令中含 token / 密码 / API Key 时，**必须**提醒用户改用环境变量，不在输出中复述明文敏感值。
4. **风险项必标注**：`-k` / 明文凭据 / 无超时 等风险场景必须在解释中标出。
5. **信息不足时追问**：构造模式缺关键参数时，明确列出需要用户补充的信息，不编造接口细节。
6. **全程中文**：解释与注意事项用简体中文；curl 命令、HTTP 头名、URL 保持原样。
7. **不做文件写操作**：不修改用户本地文件、不执行有副作用的系统命令。

## 边界

- 适用于标准 `curl` 命令行语法；不覆盖 libcurl API、Python requests、HTTPie 等其他客户端（可告知转换方向但不直接生成）。
- `bin/parse-curl.sh` 是 token 扫描式粗解析，对极复杂的多层嵌套引号组合可能不完整；Claude 会在脚本结果基础上做语义补全。
- 响应解读不替代服务端日志排查；若需定位服务端问题，建议用户查服务端日志。
