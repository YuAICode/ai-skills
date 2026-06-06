---
name: mock-data-gen
description: 按表结构 / struct / TS interface / JSON shape 生成假数据与测试种子数据,支持 JSON / SQL INSERT / CSV / NDJSON 输出格式。触发词:/mock-data-gen、帮我生成测试数据、帮我造数据、生成假数据、生成种子数据。
---

# mock-data-gen — 假数据 / 测试种子数据生成

把 SQL `CREATE TABLE`、Go/GORM struct、TypeScript interface、JSON 样例或自然语言字段描述,
转换成 N 条**真实感**测试数据,输出为 JSON 数组 / SQL INSERT / CSV / NDJSON,
字段值符合类型、约束与业务语义,唯一键不重复,外键保持引用一致。

> **所有生成数据均为假数据,仅供开发测试使用,不含真实 PII。**

## 何时触发

用户说:
- `/mock-data-gen`
- "帮我生成测试数据"
- "帮我造数据"
- "生成假数据" / "生成种子数据"
- "给这个表造 10 条 INSERT"
- "帮我生成符合这个 interface 的 JSON"
- "我需要 CSV 格式的测试数据"
- "给我生成一些中文测试用户"

## 工作流

### 1. 收集输入

从用户处拿到以下信息(缺什么问什么,再追问一次即可,不要多轮打扰):

| 输入项 | 说明 | 缺省值 |
|---|---|---|
| **结构定义** | SQL `CREATE TABLE` / Go struct / TS interface / JSON shape / 自然语言字段列表 | 必填 |
| **条数 N** | 需要生成多少条 | 默认 10 |
| **输出格式** | `json` / `sql` / `csv` / `ndjson` | 默认 `json` |
| **语言偏好** | 中文场景(中文姓名/国内手机号/省市地址等)还是国际化 | 默认按字段名/表名推断 |
| **外键约束** | 若有外键,提供父表已有的合法 ID 范围或列表 | 未提供时自动生成连续 ID |

### 2. 解析结构

- **SQL CREATE TABLE**:提取列名、类型、`NOT NULL`、`DEFAULT`、`UNIQUE`、`CHECK`、枚举(`ENUM(...)`)、主键、外键、长度限制(`VARCHAR(N)`)。
- **Go/GORM struct**:解析字段名、类型(`string`/`int`/`time.Time`/`*Type` 等)、GORM tag(`column` / `type` / `not null` / `unique` / `default` / `size`)、json tag 作为字段名。
- **TypeScript interface**:解析字段名、类型(`string`/`number`/`boolean`/`Date`/字面量联合 `'a' | 'b'`/可选 `?`)。
- **JSON 样例**:推断每个字段的类型与语义。
- **自然语言字段列表**:从描述推断类型与约束(如"手机号:11 位数字,不重复"→ `VARCHAR(11) UNIQUE NOT NULL`)。

### 3. 推断字段语义并生成真实感数据

#### 字段语义映射

| 字段名关键词(模糊匹配) | 生成策略 |
|---|---|
| `name` / `user_name` / `姓名` | 真实感人名(中文 or 英文,按语言偏好) |
| `email` / `邮箱` | `<拼音或英文>@<域名>.com` 格式,保证 `@` 前唯一 |
| `phone` / `mobile` / `手机` | 中文场景:1[3-9]XXXXXXXXX(11 位);国际:+1-XXX-XXX-XXXX |
| `id_card` / `身份证` | 18 位格式(前 17 位数字 + 1 位数字或 X),**标注为假** |
| `id` / `user_id` / `_id` | 从 1 开始的自增整数(或 UUID v4,依类型判断) |
| `created_at` / `updated_at` / `date` / `时间` | ISO 8601 时间,`created_at` ≤ `updated_at`,时序合理 |
| `age` / `年龄` | 18–65 之间的整数 |
| `amount` / `price` / `金额` / `费用` | 正数浮点,保留 2 位小数 |
| `status` / `state` / `type` | 从枚举/联合类型中随机取合法值 |
| `address` / `地址` | 中文场景:省 + 市 + 区 + 街道(均为真实省市名,门牌号为假) |
| `province` / `省` | 中国真实省/直辖市名 |
| `city` / `市` | 与 province 对应的城市名 |
| `content` / `description` / `remark` / `备注` | 1–3 句中文或英文占位文字 |
| `url` / `avatar` / `image` | `https://example.com/<slug>` 格式占位 URL |
| `score` / `rating` | 0–100(score)或 1–5(rating)浮点 |
| `is_` / `has_` / `enable` | boolean,随机 true/false |
| `gender` / `sex` / `性别` | `male`/`female` 或 `男`/`女`,依枚举定义 |
| `password` / `密码` | `<占位>` 字符串 + 标注"非真实凭证" |

#### 约束严格遵守

- `NOT NULL` / 非可选字段:不生成 `null`。
- `UNIQUE` / `unique:true`:该字段 N 条中不重复。
- `VARCHAR(N)` / `size:N`:生成值长度 ≤ N。
- `ENUM(a,b,c)` / 字面量联合:只从合法值中取。
- `DEFAULT <val>`:若字段可省略,可直接使用 default;若需显式填,使用 default 值。
- 外键:外键字段的值从用户提供或自动生成的父表主键集合中随机取(保持引用一致)。
- 时间字段:`created_at` ≤ `updated_at`(如两者均有)。
- 主键自增:从 1 或用户指定起始值开始,每条递增 1。

### 4. 输出格式

#### JSON 数组(默认)

```json
[
  {
    "id": 1,
    "name": "张伟",
    "email": "zhangwei@example.com",
    "phone": "13812345678",
    "created_at": "2025-03-15T08:30:00Z"
  }
]
```

#### SQL INSERT

```sql
-- 假数据,仅供测试
INSERT INTO `users` (`id`, `name`, `email`, `phone`, `created_at`) VALUES
(1, '张伟', 'zhangwei@example.com', '13812345678', '2025-03-15 08:30:00'),
(2, '李娜', 'lina@example.com', '15923456789', '2025-04-02 14:15:00');
```

#### CSV

```csv
id,name,email,phone,created_at
1,张伟,zhangwei@example.com,13812345678,2025-03-15T08:30:00Z
2,李娜,lina@example.com,15923456789,2025-04-02T14:15:00Z
```

#### NDJSON(每行一个 JSON 对象)

```ndjson
{"id":1,"name":"张伟","email":"zhangwei@example.com","phone":"13812345678","created_at":"2025-03-15T08:30:00Z"}
{"id":2,"name":"李娜","email":"lina@example.com","phone":"15923456789","created_at":"2025-04-02T14:15:00Z"}
```

### 5. 端到端示例:从 CREATE TABLE 到 5 条 INSERT

**输入结构:**

```sql
CREATE TABLE orders (
  id          INT PRIMARY KEY AUTO_INCREMENT,
  user_id     INT NOT NULL,                          -- 外键,users.id
  order_no    VARCHAR(20) UNIQUE NOT NULL,
  status      ENUM('pending','paid','shipped','done') NOT NULL DEFAULT 'pending',
  amount      DECIMAL(10,2) NOT NULL,
  note        TEXT,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**用户需求:**生成 5 条,SQL INSERT 格式,user_id 取自 users.id 范围 1–3,中文场景。

**输出:**

```sql
-- ⚠️ 以下均为假数据,仅供开发测试,请勿用于生产环境
INSERT INTO `orders` (`id`, `user_id`, `order_no`, `status`, `amount`, `note`, `created_at`, `updated_at`) VALUES
(1, 2, 'ORD-20250315-00001', 'paid',    128.50, '请尽快发货',           '2025-03-15 09:12:00', '2025-03-15 11:30:00'),
(2, 1, 'ORD-20250402-00002', 'pending',  59.90, NULL,                   '2025-04-02 14:05:00', '2025-04-02 14:05:00'),
(3, 3, 'ORD-20250410-00003', 'shipped', 299.00, '易碎品,轻拿轻放',      '2025-04-10 08:00:00', '2025-04-11 10:20:00'),
(4, 2, 'ORD-20250418-00004', 'done',     45.00, NULL,                   '2025-04-18 16:30:00', '2025-04-19 09:00:00'),
(5, 1, 'ORD-20250501-00005', 'paid',    780.00, '劳动节促销订单',       '2025-05-01 10:00:00', '2025-05-01 10:45:00');
```

**说明:**
- `order_no` 5 条各不相同(UNIQUE 约束满足)
- `user_id` 从 {1, 2, 3} 中随机取(外键引用一致)
- `status` 只取 `ENUM` 中的合法值
- `created_at` ≤ `updated_at`(时序合理)
- `amount` 保留 2 位小数
- `note` 允许 NULL(TEXT 无 NOT NULL)

### 6. 中文场景支持

当字段或用户需求涉及中国本地化时,按以下规则生成:

| 字段类型 | 生成规则 |
|---|---|
| 中文姓名 | 常见百家姓(王/李/张/刘/陈…)+ 常见名字(伟/芳/娜/秀英…) |
| 手机号 | `1[3-9]\d{9}`(11 位),首位 13/14/15/16/17/18/19,第三位不超出运营商号段 |
| 身份证 | 18 位格式:6 位地区码 + 8 位生日(YYYYMMDD)+ 3 位顺序码 + 1 位校验码(数字或 X),**输出时附注"⚠️ 假身份证号,仅供测试"** |
| 省市区 | 真实省/直辖市/自治区名;城市与省份对应(不会出现"上海市广州市") |
| 详细地址 | `<省><市><区> <真实路名>路 <N> 号 <M> 室`(路名为占位,不暗示真实地址) |
| 公司名称 | `<城市><行业>有限公司` 格式(均为虚构) |
| 银行卡 | 16–19 位数字,**附注"⚠️ 假卡号,仅供测试"**,不生成通过 Luhn 校验的真实卡号 |

> **重要:**中文手机号、身份证号、银行卡号均为格式合规但**内容虚构**的假数据,
> 明确标注"仅供测试",不可作为真实凭证使用。

### 7. 信息不足时追问

若以下关键信息缺失且影响生成质量,一次性列出所有疑问:

- 结构定义:必须有,如果完全缺失则请用户提供
- 外键引用:有外键且未提供父表 ID 范围时,说明将自动生成范围并让用户确认
- 枚举值不明确:询问合法取值列表
- 多义字段(如 `type` 无枚举约束):列出几个可能的取值并让用户选择

## 输出模板

生成后按以下结构回复:

```
## 生成结果

> ⚠️ 以下均为假数据,仅供开发/测试使用。请勿将手机号、身份证号等字段误用于真实场景。

<生成的数据块>

## 说明

- 条数:N 条
- 格式:JSON / SQL INSERT / CSV / NDJSON
- 关键约束处理:
  - UNIQUE 字段 <字段名>:N 条中不重复
  - 外键 <字段名> → <父表>(<父表主键范围>)
  - 枚举 <字段名>:只取 <合法值列表> 中的值
  - 时序:<created_at> ≤ <updated_at>
- 如需调整(条数 / 格式 / 字段分布 / 语言),直接告诉我
```

## 硬规则

1. **假数据声明**:输出前必须有明确的"假数据,仅供测试"声明。中文手机号、身份证、银行卡号一律附注"⚠️ 假"字样。
2. **UNIQUE 不重复**:标注 UNIQUE 或 unique:true 的字段,N 条之间绝对不重复。
3. **外键引用一致**:外键字段的值只取合法父键集合中的值,不生成不存在的引用。
4. **枚举合法**:ENUM / 字面量联合类型只取声明的合法值,不超出范围。
5. **不生成可被误用的真实凭证**:不生成通过 Luhn 校验的银行卡号;不生成能通过公民身份校验的真实身份证号;密码字段一律用占位字符串。
6. **类型匹配**:整数字段不生成小数;VARCHAR(N) 值长度 ≤ N;DECIMAL(p,s) 保留 s 位小数。
7. **时序合理**:`created_at` ≤ `updated_at`;有 `start_date` 和 `end_date` 时 start ≤ end。
8. **不臆断**:字段语义不明确时优先追问,不强行猜测并生成可能误导的值。
9. **不做写操作**:只输出数据文本,不向任何数据库写入、不执行任何命令。

## 边界

- 纯 Claude 驱动,无需 bin 脚本或外部工具。
- 生成量无硬性上限,但超过 100 条时建议分批请求以保证质量。
- 不支持生成加密/压缩二进制格式(如 Parquet、Avro)。
- 复杂 CHECK 约束(如跨列比较 `CHECK (end_date > start_date + 7)`)会尽力遵守,
  但不保证 100% 机器可校验;生成后请人工复核。
- 不处理 PL/pgSQL 函数、触发器、视图定义,仅处理列约束。
