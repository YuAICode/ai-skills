---
name: json-yaml-doctor
description: 校验 / 格式化 / 解释 JSON·YAML(·TOML),报错给中文定位。当用户说「校验 json / check yaml / json 格式化 / yaml 报错 / toml 检查 / json-yaml-doctor / 检查这个配置文件」时触发。脚本负责解析报错,Claude 负责解释常见坑(YAML 缩进/tab、JSON 尾逗号/单引号、键重复等)并给修法;也可应用户要求做 JSON↔YAML 互转。
---

# json-yaml-doctor — JSON / YAML / TOML 校验与中文报错解读

把晦涩的 parser 报错翻译成中文,给出精确行列定位,解释常见坑,并提供格式化输出。

## 何时触发

用户说:
- "校验这个 json / 检查 yaml 有没有问题 / toml 报错了"
- "json 格式化 / yaml 格式化"
- "这个配置文件解析失败 / check yaml / json-yaml-doctor"
- "帮我把 json 转成 yaml"(需 pyyaml)

## 用法

### 1. 跑校验脚本

```bash
bash <skill>/bin/check.sh <文件路径>           # 校验语法
bash <skill>/bin/check.sh <文件路径> --format  # 校验 + 输出美化后内容
bash <skill>/bin/check.sh -                    # 从 stdin 读(自动探测类型)
```

脚本自动按扩展名(或内容探测)判类型,依次:

| 格式 | 依赖 | 无依赖时 |
| ---- | ---- | -------- |
| JSON | python3 标准库(json) | 永远可用 |
| YAML | python3 + pyyaml | 提示 `pip install pyyaml` 并 exit 0 跳过 |
| TOML | python3 3.11+ tomllib | 提示并 exit 0 跳过 |

退出码:
- `0` — 合法(或依赖缺失跳过)
- `2` — 语法错误(附中文定位)

环境变量:
- `PYTHON_BIN` — 覆盖 python 解释器路径(默认 `python3`),测试用

### 2. Claude 解读与修复

拿到脚本输出后,Claude 会:
1. **翻译**:把行列 + 原始 parser 报错用中文讲清楚
2. **解释根因**:常见坑一览:
   - **JSON 尾逗号**:最后一个元素后面多了逗号(标准 JSON 不允许)
   - **JSON 单引号**:键或值用了 `'…'` 而非 `"…"`
   - **JSON 键重复**:同一对象出现两个相同键(行为未定义,易出 bug)
   - **YAML Tab 缩进**:YAML 禁止用 Tab,只能空格
   - **YAML 缩进不一致**:子层缩进量与父层不对齐
   - **YAML 特殊字符未引号**:含 `:` `#` `{` `}` 等需加引号
   - **TOML 键重复 / 日期格式**:常见 TOML 解析坑
3. **给出修法**:显示修正前 → 修正后对比

### 3. JSON ↔ YAML 互转(需 pyyaml)

直接告诉 Claude "把这段 JSON 转成 YAML"或"把这个 yaml 文件转成 json",Claude 会调用 python3 + yaml 完成转换并输出结果。

## 边界

- JSON 校验始终可用(python3 标准库);YAML 需 pyyaml,TOML 需 py 3.11+
- 只检查语法,不校验业务 schema(如 OpenAPI 合法性需另外工具)
- 从 stdin 读时(`-`),扩展名无法自动判断,优先按内容首字符猜测(JSON:`{`/`[`;TOML:含 `=`;否则当 YAML)
- 不修改原文件,只输出报告或美化内容
