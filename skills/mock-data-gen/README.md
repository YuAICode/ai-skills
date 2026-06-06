# mock-data-gen

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/mock-data-gen)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

按表结构 / Go struct / TS interface / JSON shape 生成**假数据与测试种子数据**,
支持 JSON 数组 / SQL INSERT / CSV / NDJSON 输出格式,字段值符合类型、约束与业务语义。
支持中文场景(中文姓名 / 国内手机号 / 省市地址等)。

> ⚠️ 所有生成数据均为假数据,仅供开发测试使用,不含真实 PII。

## 安装

把本目录拷进 Claude Code 的 skills 目录,重启后即可触发:

```bash
# 全局(所有项目可用)
cp -r mock-data-gen ~/.claude/skills/

# 或项目级(只在当前项目生效)
cp -r mock-data-gen .claude/skills/
```

## 用法

### 基本调用

直接说出触发词之一,并提供结构定义:

```
/mock-data-gen
帮我生成测试数据
帮我造数据
生成假数据
生成种子数据
给这个表造 10 条 INSERT
```

### 支持的输入结构

| 结构格式 | 示例 |
|---|---|
| SQL `CREATE TABLE` | MySQL / PostgreSQL / SQLite 建表语句 |
| Go / GORM struct | 含 `gorm:` tag 的 struct 定义 |
| TypeScript interface | 含可选字段与字面量联合类型 |
| JSON 样例 | 一条示例 JSON,推断字段类型 |
| 自然语言描述 | "用户表:ID、姓名、手机号(不重复)、注册时间" |

### 输出格式

| 格式 | 说明 |
|---|---|
| `json`(默认) | JSON 数组 |
| `sql` | SQL INSERT 语句 |
| `csv` | 首行为列名的 CSV |
| `ndjson` | 每行一个 JSON 对象(Newline Delimited JSON) |

### 示例:从 CREATE TABLE 生成 5 条 SQL INSERT

**输入:**

```sql
CREATE TABLE users (
  id         INT PRIMARY KEY AUTO_INCREMENT,
  name       VARCHAR(20) NOT NULL,
  email      VARCHAR(100) UNIQUE NOT NULL,
  phone      VARCHAR(11) UNIQUE NOT NULL,
  gender     ENUM('male','female') NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

说:"生成 5 条 SQL INSERT,中文场景"

**输出:**

```sql
-- ⚠️ 假数据,仅供开发测试,请勿用于生产环境
INSERT INTO `users` (`id`, `name`, `email`, `phone`, `gender`, `created_at`) VALUES
(1, '张伟',   'zhangwei@example.com',  '13812345678', 'male',   '2025-03-15 09:00:00'),
(2, '李娜',   'lina@example.com',      '15923456789', 'female', '2025-04-02 14:30:00'),
(3, '王芳',   'wangfang@example.com',  '18034567890', 'female', '2025-04-18 11:00:00'),
(4, '刘洋',   'liuyang@example.com',   '17645678901', 'male',   '2025-05-01 08:45:00'),
(5, '陈秀英', 'chenxiuying@example.com','13956789012', 'female', '2025-05-20 16:20:00');
```

### 中文场景支持

| 字段类型 | 生成规则 |
|---|---|
| 姓名 | 常见百家姓 + 常见名字 |
| 手机号 | `1[3-9]XXXXXXXXX`(11 位,格式合规但内容虚构) |
| 身份证 | 18 位格式,**附注"⚠️ 假身份证号"** |
| 省市区 | 真实省市名 + 虚构门牌号 |
| 公司名 | `<城市><行业>有限公司`(均为虚构) |

## 硬规则摘要

- `UNIQUE` 字段:N 条中绝对不重复
- 外键字段:只取合法父键集合中的值
- `ENUM` / 字面量联合:只取声明的合法值
- 时序合理:`created_at` ≤ `updated_at`
- 手机号 / 身份证 / 银行卡号均为假数据,明确标注
- 不执行任何命令,不向数据库写入

完整工作流、模板与硬规则见 [SKILL.md](./SKILL.md)。

## License

[MIT](../../LICENSE)
