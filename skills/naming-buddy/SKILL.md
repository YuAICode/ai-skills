---
name: naming-buddy
description: 命名困难症救星。给一段逻辑/用途描述 + 语言 → 建议好的变量/函数/类/文件/常量/布尔名,中英对照解释。触发词:'/naming-buddy'、'帮我起个名字'、'这个变量叫什么好'、'给这个函数命名'、'命名建议'。
---

# naming-buddy — 命名困难症救星

给一段逻辑/用途描述 + 目标语言,得到 **3-5 个候选名**、推荐理由、以及原名/坏味道诊断。
告别 `data`、`temp`、`flag`、`info`、`manager`——让名字直接说清意图。

## 何时触发

用户说:
- `/naming-buddy`
- `帮我起个名字`
- `这个变量叫什么好`
- `给这个函数命名`
- `命名建议`
- `这个名字好不好`
- `xxx 这个名字有没有问题`
- `帮我看看这几个命名`
- `类名怎么起`、`文件名叫什么`、`常量名叫什么`

## 工作流

### 第 1 步:搞清三件事

在给出任何候选名之前,必须先明确:

1. **命名类型**:变量 / 函数 / 类 / 接口 / 文件 / 包 / 常量 / 布尔 / 枚举 / 参数
2. **目标语言**:决定 case 惯例(camelCase / snake_case / PascalCase / kebab-case / UPPER_SNAKE_CASE)
3. **职责描述**:它做什么、存什么、代表什么——这是命名的根本依据

若用户没有提供语言或职责描述,**先追问**,不要凭空猜测。追问示例:
- "请问是哪种语言?Go / Python / TypeScript / Java / Swift / Rust / Dart…?"
- "能描述一下这个函数/变量的具体职责吗?它做什么事情?"
- "它是个布尔值还是函数?读来还是写去?"

### 第 2 步:给 3-5 个候选名

按推荐度从高到低排列,格式:

```
候选名(按推荐度排):
1. <名字>  — <一句中文理由:为什么推荐,有什么优势>
2. <名字>  — <一句中文理由>
3. <名字>  — <一句中文理由>
[4. <名字>  — (适用特定场景时)]
[5. <名字>  — (适用特定场景时)]
```

**给候选名的原则:**
- 第 1 名:最符合该语言惯例 + 意图最清晰的
- 第 2-3 名:语义相近但侧重点不同(更简洁 / 更明确 / 更符合项目词汇表)
- 第 4-5 名:适用于特定上下文(如有对应配对名、领域术语时)
- 每个名字都附一句中文理由,说明**为什么**而不只是"这样更清晰"

### 第 3 步:坏味道诊断

若用户给出了原名,或候选时需要对比,**主动指出**以下坏味道:

| 坏味道类型 | 典型例子 | 问题所在 |
|-----------|---------|---------|
| 过于泛化 | `data`、`info`、`result`、`value`、`item`、`obj` | 什么都能叫这个,看不出业务含义 |
| 动作名词太泛 | `manager`、`handler`、`processor`、`util`、`helper`、`service`(滥用) | 掩盖真实职责 |
| 临时占位 | `temp`、`tmp`、`foo`、`bar`、`xxx`、`test2` | 临时名字进了正式代码 |
| 布尔无前缀 | `verified`、`active`、`loaded` | 不加 is/has/can 容易误用为名词 |
| 匈牙利命名 | `strName`、`boolFlag`、`intCount` | 类型信息放名字里,现代 IDE 已无必要 |
| 过度缩写 | `usrCntr`、`getMsgCnt`、`calcRcvdPkts` | 三个月后连自己都看不懂 |
| 拼音混入 | `yongHu`、`zhanghao` | 项目统一英文时不要用拼音 |
| 序号命名 | `user1`、`data2`、`list3` | 区分靠数字而不是语义 |
| 类型即名字 | `userList`、`nameString`、`countInt` | 名字里带类型后缀,通常多余 |
| 反义不对称 | `getUser` + `removeUser` 但本应对称 `addUser` + `removeUser` | 动词不一致破坏 API 可读性 |

### 第 4 步:附上语言惯例提示(如有必要)

若用户对 case 约定不熟悉,或给出的名字 case 不对,给一句提示:

```
惯例提示:<语言> 中 <命名类型> 用 <case 形式>。
示例:Go 中导出函数用 PascalCase(如 GetUser),内部函数用 camelCase(如 getUser)。
```

## 输出模板

```markdown
## 命名建议

**命名类型:**<变量/函数/类/…>
**语言:**<目标语言>(惯例:<camelCase / snake_case / PascalCase / …>)
**职责:**<一句话复述理解,确认没有歧义>

**候选名(按推荐度排):**
1. `<名字>`  — <理由>
2. `<名字>`  — <理由>
3. `<名字>`  — <理由>
[4. `<名字>`  — <理由,适用场景>]
[5. `<名字>`  — <理由,适用场景>]

**坏味道诊断:**
[若原名存在问题]
- 原名 `<xxx>` 的问题:<具体说明为什么不好>
[若无明显问题]
- 原名无明显坏味道。

**惯例提示:**<若用户的 case 不符合语言惯例时给出;若无问题则省略>
```

## 命名惯例速查表

| 语言 | 变量 | 函数/方法 | 类/类型 | 常量 | 文件名 |
|------|------|----------|--------|------|--------|
| **Go** | camelCase | camelCase(内) / PascalCase(导出) | PascalCase | 全大写 `MAX_SIZE` 或包级 camelCase | snake_case.go |
| **Python** | snake_case | snake_case | PascalCase | UPPER_SNAKE_CASE | snake_case.py |
| **TypeScript / JS** | camelCase | camelCase | PascalCase | UPPER_SNAKE_CASE | kebab-case.ts / PascalCase.tsx |
| **Java** | camelCase | camelCase | PascalCase | UPPER_SNAKE_CASE | PascalCase.java |
| **Kotlin** | camelCase | camelCase | PascalCase | UPPER_SNAKE_CASE | PascalCase.kt |
| **Rust** | snake_case | snake_case | PascalCase | UPPER_SNAKE_CASE | snake_case.rs |
| **Swift** | camelCase | camelCase | PascalCase | lowerCamelCase | PascalCase.swift |
| **Dart / Flutter** | camelCase | camelCase | PascalCase | lowerCamelCase | snake_case.dart |
| **C#** | camelCase(私有) / PascalCase(公有) | PascalCase | PascalCase | PascalCase / UPPER_SNAKE_CASE | PascalCase.cs |
| **Ruby** | snake_case | snake_case | PascalCase | UPPER_SNAKE_CASE | snake_case.rb |
| **CSS / HTML** | kebab-case | — | — | — | kebab-case.css |
| **Shell / Bash** | snake_case | snake_case | — | UPPER_SNAKE_CASE | snake-case.sh |

**布尔命名专项:**

| 语言 | 推荐前缀 | 示例 |
|------|---------|------|
| Go | `is` / `has` / `can` / `should` | `isActive`、`hasPermission` |
| Python | `is_` / `has_` / `can_` | `is_verified`、`has_children` |
| TypeScript/JS | `is` / `has` / `can` / `should` | `isLoading`、`canSubmit` |
| Java/Kotlin | `is` / `has` / `can` | `isEnabled`、`hasError` |
| Swift/Dart | `is` / `has` / `can` | `isSelected`、`canEdit` |

## 坏味道清单

**过于泛化的词(见到要警惕):**

```
data  info  result  value  item  obj  object  entity  record
temp  tmp   buf     flag   state status  content  payload
manager  handler  processor  util  utils  helper  service(滥用)
```

**布尔命名常见错误:**
- `verified` → 应为 `isVerified`
- `active` → 应为 `isActive`
- `loaded` → 应为 `isLoaded`
- `error` → 用于布尔时应为 `hasError`

**函数/方法命名动词推荐:**

| 动作 | 推荐动词 | 避免 |
|------|---------|------|
| 取数据 | `get`、`fetch`、`load`、`find`、`query` | `retrieve`(太正式)、`obtain` |
| 检查/判断 | `is`、`has`、`can`、`check`、`validate` | `verify`(常与"核验"混) |
| 创建 | `create`、`build`、`make`、`new`、`init` | `generate`(通常指生成内容,非对象) |
| 转换 | `to`、`from`、`convert`、`transform`、`map`、`parse` | `change` |
| 更新 | `update`、`set`、`apply`、`patch`、`modify` | `edit`(通常是 UI 层用词) |
| 删除 | `delete`、`remove`、`clear`、`purge` | `destroy`(过于强烈,慎用) |
| 发送 | `send`、`publish`、`dispatch`、`emit`、`push` | `do`(完全不说明意图) |

## 硬规则

1. **意图优先**:名字表达"这东西是什么 / 做什么",不表达"它的类型是什么"。
2. **遵循语言惯例**:camelCase / snake_case 等不能混用,Go 导出用 PascalCase 不能省。
3. **布尔必须有前缀**:is/has/can/should 等;不加前缀的布尔容易被误当名词使用。
4. **不臆造领域术语**:不确定业务含义时先问,不随便编造词汇。
5. **长度适中**:
   - 过短:缩写到看不懂(`usrCntr`、`msgCnt`)→ 展开
   - 过长:超过 3-4 个单词的驼峰通常可以缩减(`getUserByIdFromDatabase` → `findUser`)
6. **项目词汇表一致**:若项目里用 `user` 就不要用 `account`;用 `create` 就不要对称写 `add`。
7. **不做任何写操作**:只给建议;不修改文件、不执行命令、不推送代码。

## 边界

- 纯 Claude 驱动,无需 bin 脚本或外部工具。
- 只做命名建议,不做代码重构;若需要批量重命名,提示用 IDE 重构功能。
- 不对框架专有命名(如 Django Model 字段、React Hook 前缀 `use`)做语言级规则覆盖——框架惯例优先。
- 若项目有既有命名规范文档(如 Google Style Guide、项目 CONTRIBUTING.md),告知 Claude 后以该规范为准。
