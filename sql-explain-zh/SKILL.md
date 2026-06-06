---
name: sql-explain-zh
description: 解读慢查询的 EXPLAIN 输出,给中文优化建议(索引/扫描行数/回表/filesort/临时表)。当用户说「EXPLAIN 帮我看下/这个查询好慢/SQL 优化/慢查询分析/explain 结果看不懂」时触发。
---

# sql-explain-zh — EXPLAIN 中文解读 + 优化建议

把 MySQL `EXPLAIN` 输出收敛成"每行的中文含义 + 具体能做什么优化",不用再对着英文文档猜。

## 何时触发

- 用户说"帮我看下这个 EXPLAIN"、"这个 SQL 好慢"、"慢查询优化"、"explain 结果看不懂"
- 用户粘贴了 `EXPLAIN` 输出(含 id/select_type/table/type/key/rows/Extra 等列)
- 用户想知道某个 SQL 会不会走索引、会不会全表扫描

## 用法

### 方式 A：有 MySQL 连接 — 用脚本跑 EXPLAIN

```bash
# 设置连接环境变量(标准 MYSQL_* 变量)
export MYSQL_HOST=127.0.0.1
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASSWORD=secret
export MYSQL_DATABASE=mydb

# 跑 EXPLAIN(SQL 作参数)
bash <skill>/bin/explain.sh "SELECT * FROM orders WHERE user_id = 1"

# 或从 stdin 传 SQL
echo "SELECT * FROM orders WHERE user_id = 1" | bash <skill>/bin/explain.sh
```

脚本输出 `EXPLAIN` 结果后,把输出粘给 Claude 解读。

### 方式 B：无 MySQL 连接(或只有 EXPLAIN 结果)

直接把 EXPLAIN 结果粘给 Claude,说"帮我解读这个 EXPLAIN"即可。无需脚本。

### 流程

1. **拿到 EXPLAIN 结果**:用户粘贴 或 `bin/explain.sh` 跑出来。
2. **逐行解读**:Claude 对每个 EXPLAIN 行逐列分析(见解读模板)。
3. **给出中文优化建议**:该加什么索引、为什么慢、能否避免回表/filesort/临时表。
4. **如有缺口就问**:缺少表结构/索引定义/数据量时,明确告诉用户需要哪些信息。

## 解读模板

```markdown
## EXPLAIN 解读

### 查询概览
（一句话:这是什么查询、预期扫哪几张表、关联逻辑）

### 逐行分析

| 行 | table | type | key | rows | Extra | 风险 |
|----|-------|------|-----|------|-------|------|
| 1  | orders | ALL | NULL | 500000 | Using filesort | 🔴 全表扫描 + filesort |
| 2  | users  | eq_ref | PRIMARY | 1 | — | ✅ 主键等值 |

**各列说明：**

- **type**（访问类型,从优到劣）：
  `system` > `const` > `eq_ref` > `ref` > `range` > `index` > `ALL`
  - `ALL`：全表扫描,**最差**,rows 大时必须加索引。
  - `index`：索引全扫,比 ALL 好但仍可能慢。
  - `range`：索引范围扫描,`WHERE id BETWEEN 1 AND 100` 之类。
  - `ref`：非唯一索引等值匹配。
  - `eq_ref`：唯一索引等值,JOIN 时常见。
  - `const`/`system`：最优,主键/唯一索引点查。

- **key**：实际用到的索引;`NULL` = 没用任何索引。
- **rows**：预估扫描行数,越大越慢。
- **Extra**（常见危险信号）：
  - `Using filesort`：ORDER BY 用不上索引,需额外排序。
  - `Using temporary`：用了临时表,GROUP BY/DISTINCT/子查询常见。
  - `Using index`：覆盖索引,不回表,✅ 好事。
  - `Using where`：Server 层再过滤,索引后还有额外筛选。
  - `Using join buffer`：JOIN 没有走对端索引,内存 Buffer 处理。

### 问题 & 优化建议

1. **问题一：<table> 全表扫描(type=ALL,rows=500000)**
   - 原因：WHERE 条件列 `user_id` 无索引。
   - 建议：`ALTER TABLE orders ADD INDEX idx_user_id (user_id);`
   - 预期效果：rows 从 500000 → 约 N,type 变 ref。

2. **问题二：Using filesort**
   - 原因：ORDER BY `created_at` 与过滤条件不在同一复合索引。
   - 建议：`ADD INDEX idx_user_created (user_id, created_at);`（复合索引覆盖过滤+排序）
   - 预期效果：Extra 消去 Using filesort。

3. **回表说明**（若适用）
   - key 列命中二级索引但 SELECT 了非索引列,需回表查主键行。
   - 建议：把高频 SELECT 列加进覆盖索引,或只 SELECT 需要的列。

### 结论

（总结:最大瓶颈在哪、优先做哪一件事、预估改完后扫描行数量级变化）
```

## 硬规则

1. **不臆造表结构**:没有 `SHOW CREATE TABLE` 就不猜索引列类型/选择度,需要时明确问用户。
2. **缺信息就问**:数据量、索引定义、完整 SQL、执行计划(FORMAT=JSON)都可能影响判断。
3. **只读不改**:本 skill 只分析、建议;不向数据库发任何 `ALTER`/`CREATE`/`DROP` 语句,建议以注释块形式呈现。
4. **不臆断优化效果**:只给方向和理由,无法在没跑 `EXPLAIN` 的情况下承诺"性能提升 X 倍"。
5. **回表/filesort/临时表必须明确指出**:这三类是慢查询最常见根因,每次都要检查 Extra 列。

## 边界

- 主要针对 MySQL(含 MariaDB)的 `EXPLAIN` 格式;PostgreSQL `EXPLAIN ANALYZE` 格式不同,可解读但需说明。
- `bin/explain.sh` 只跑 `EXPLAIN`(不跑 `EXPLAIN ANALYZE`),不对生产数据库做任何写操作。
- 没有 mysql 客户端或连接信息时,脚本优雅提示,用户手动粘贴 EXPLAIN 结果即可——核心解读全靠 Claude。
