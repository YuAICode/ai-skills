---
name: slack-to-spec
description: 把某个 Slack 频道一段时间内的讨论收敛成一份"可落地需求"spec 文档。用户以 `/slack-to-spec <频道> <时间范围>` 调用时触发。读频道+决策密集的 thread+关联 canvas doc,抽取「需求点 / 决策(含撤销轨迹) / 待定问题」,按固定模板产出结构化、可追溯、能直接喂开发的 markdown。Use when the user wants to turn Slack discussion into a landable requirement/spec.
---

# Slack → 可落地需求 (slack-to-spec)

把零散的 Slack 讨论收敛成开发能照着干、三个月后还能回溯"为啥这么定"的需求文档。
核心价值不是"总结",是**抓住决策(尤其被推翻/取代的方案)+ 拎出隐藏的开发需求 + 划清开工红线**。

## 用法

```
/slack-to-spec <频道> [时间范围]
```

- `<频道>`:频道 ID(如 `C0XXXXXXX`)或频道名(如 `#产品_增长`)。给名字就先用 `slack_search_channels` 解析成 ID。
- `[时间范围]`(可选,缺省 `7d`):
  - 相对:`24h` / `3d` / `7d` / `2w`(从现在往前)
  - 绝对区间:`2026-06-01..2026-06-05`
  - 单个起点:`2026-06-01`(到现在)

示例:
- `/slack-to-spec C0XXXXXXX 3d`
- `/slack-to-spec #产品_增长_商业化 2026-06-01..2026-06-05`

## 依赖工具

Slack MCP(按需 `ToolSearch` 加载):`slack_search_channels` / `slack_read_channel` / `slack_read_thread` / `slack_read_canvas`。

## 流程

### 1. 解析 args
- 拆出 `<频道>` 和 `[时间范围]`。频道是名字 → `slack_search_channels` 拿 ID。
- 把时间范围算成 Unix epoch 的 `oldest` / `latest`(`slack_read_channel` 的入参是 epoch ts 字符串)。用 Bash `date` 算,例:
  ```bash
  # 相对 7d
  oldest=$(date -v-7d +%s)            # macOS;Linux: date -d '7 days ago' +%s
  # 绝对区间 A..B
  oldest=$(date -j -f '%Y-%m-%d' 2026-06-01 +%s)   # macOS
  latest=$(date -j -f '%Y-%m-%d' 2026-06-05 +%s)
  ```
  缺省 7d。latest 缺省 = now(不传)。

### 2. 读频道
- `slack_read_channel(channel_id, oldest, latest, limit=100)`。窗口大就翻页(用返回的 cursor)。
- 扫一遍消息,标出 **决策密集 / 需求相关**的 thread(reply 多、@ 多人、带方案 doc、出现"定了/改成/取消/不做了/共识"等词)。忽略纯寒暄、抱团通知、机器人巡检告警。

### 3. 读关键 thread
- 对 step 2 选中的 thread 逐个 `slack_read_thread(channel_id, message_ts)`。
- 重点抓:谁拍的板、依据、有没有"先定 X 后又推翻改 Y"的**反转**(这是决策日志最值钱的部分)。

### 4. 读关联 doc(很重要,别漏)
- 消息里贴的 Slack doc(`application/vnd.slack-docs`,文件 ID 形如 `F0XXXXXXXXX`)**可读**:`slack_read_canvas(canvas_id=<file_id>)` 拿 markdown 正文。把奖池金额/规则/分工等细节并进 spec。
- PDF / 图片(`application/pdf`、`image/*`)**读不到**,只有文件名 —— 在 spec §来源里列出文件 ID,并在受影响的章节标"待补(PDF/图,需人贴正文)"。**不要臆造内容**。

### 5. 合成 spec
按下面模板产出。规则见「硬规则」。

### 6. 落盘 + 报告
- 写到文件(默认工作区根目录 `<topic-slug>-spec.md`;若在某 repo 任务里,问用户放 `docs/prd/` 还是 `docs/plans/`)。
- 报告:产出路径 + 读了几条消息/thread/doc + 明确列出"读不到、需人补"的缺口。

## Spec 模板

```markdown
# <需求名> — 可落地需求 (Spec)

> 来源:Slack `#<频道名>` (<channel_id>),<时间范围> 讨论收敛
> 状态:草稿 V0.1(待 <下次对齐节点> 拍板)
> 抽取:Claude(AI 采集) → 待 <relevant owners> 对账拍板

## 1. 背景 / 要解决什么
（一两段,从讨论提炼;带上关键约束/数据）

## 2. 决策日志 ★最容易丢 / 本文档核心
| # | 决策 | 结论 | 拍板人 | 依据/时间(北京时间) | 被撤销/取代的方案 |
|---|---|---|---|---|---|
| D1 | ... | ... | @who | MM-DD HH:MM | ~~旧方案~~（被 Dx 取代,注明时间）|
> 反转/撤销必须单独成行或用删除线标出 —— 这是回溯"为啥这么定"的关键。

## 3. 需求点(可验收)
### 3.x <模块> — P0/P1,<负责人>
- [ ] ACn: <可测的描述,不是"优化体验">

## 4. 影响面 / Blast radius
- [ ] 各端/各 repo 勾选;若涉及共享契约(如 swagger)标注 fan-out 范围

## 5. 开放问题(未拍板,别开工对应模块)
- Qn: <问题> —— <谁提的,未答>

## 6. 时间线
| 里程碑 | 日期 |

## 7. 来源(可回溯)
- <北京时间> — <一句话>(N replies)· ts `<message_ts>`
- 关联 doc/PDF(文件 ID):<可读的已并入 / PDF 图待补>
```

## 硬规则(今天踩坑沉淀,务必照做)

1. **时间一律显示北京时间(CST),并在末尾保留 `ts` 锚点**。ts 是 Slack 消息时间戳,既是时间也是重新打开 thread 的精确句柄,不能丢。优先用 Slack 自己渲染的 CST 时间,别手算 epoch。`F0B...` 这种是**文件 ID 不是时间戳**,别当时间转。
2. **决策日志必须有"被撤销/取代的方案"这一列/这一项**。上午定的、下午被推翻的,要留痕 + 注明取代时间。这是整份文档最值钱的地方。
3. **区分可读 vs 不可读来源**:Slack doc(canvas)用 `slack_read_canvas` 读正文并入;PDF/图读不到就**老实标缺口**,绝不臆造。
4. **不臆断**:拿不准、读不到的,标"待确认/待补",不要编。
5. **拎隐藏需求**:讨论里一句"目前没有,需要后续开发"这种,要升级成明确的 AC(常被埋在长 thread 里)。
6. **划开工红线**:还没拍板的(端选型/合规/金额/命名等)进 §5,并标"别开工对应模块"。
7. 产出语言:中文 + 英文,不引入其他自然语言。
8. **不做任何写操作**:本 skill 只读 Slack、只产出本地文档;不往 Slack 发消息、不碰任何线上系统。

## 衔接

spec 出来后,可直接喂 `writing-plans` skill 出开发 plan → TDD 执行。
