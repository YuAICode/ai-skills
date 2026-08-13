# figma-to-page 设计文档

- 日期:2026-08-13
- 状态:已批准,待实现
- Skill 目录:`skills/figma-to-page/`

## 问题

从 Figma 设计稿写页面,还原度长期不达标。根因**不是**模型不会写样式,而是:

1. **输入信息量不足** —— 常见做法是丢一张截图让模型「看图猜数值」。间距、字号、行高、色值全靠目测,必然对不上。
2. **没有闭环校验** —— 写完凭肉眼说「差不多」就收工,偏差无法量化,也就无法收敛。
3. **没有地基** —— 每个页面独立写样式,同一个灰色在三个页面出现三个值;改设计要改 N 处。

## 目标

一个跨项目、跨技术栈通用的 skill,把「看图猜」换成「拉结构化真值 + 量化闭环」,让页面**一次基本还原**。

非目标(明确不做):

- 不做交互与动效还原 —— 静态视觉先收敛,交互是第二轮的事。
- 不做整站/多页面批量 —— 一轮一个 frame,理由见「上下文纪律」。
- 不生成独立 scaffold —— 产物必须长进宿主项目的 theme 层与组件规范里。

## 关键决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 设计数据来源 | 官方 Figma MCP(`mcp__*_Figma__*`) | 已接入零配置,且独有 `get_variable_defs`(token)与 `get_code_connect_map`(组件映射),是 token 对账的地基 |
| 是否引入 Figma-Context-MCP(Framelink) | **不引入** | 能力是官方 MCP 的子集(无 variables / 无 assets / 无 code connect),还要额外签 API token |
| 是否引入 FigmaToCode 作为依赖 | **不作为依赖,只提炼其映射规则** | 其 `packages/backend` 是 `private: true` 未发 npm,且依赖 `@figma/plugin-typings`(输入是插件运行时节点,非 MCP JSON);其产物是独立 scaffold,会绕过宿主项目 token 层 |
| 还原度收敛阈值 | **整体像素差异 ≤ 1%** | 用户指定 |
| 项目无 token 层时 | **主动建立** | 否则每轮都在硬编码,skill 的价值只剩一半 |
| 截图来源 | 探测优先级链,逐级降级 | 见下 |
| 像素 diff 实现 | Pillow(已装 12.2.0),缺失则降级为模型肉眼对比 | 合集惯例:外部工具缺失要优雅降级,不能崩 |

### 截图来源探测链

1. 项目内脚本(`scripts/run_app_*`、`package.json` 的 dev script)
2. Web:gstack `/browse` 无头浏览器
3. iOS 原生:gstack `/ios-qa`
4. 兜底:要求用户手动提供截图

**每一级探测失败都要明说降级原因,不静默跳过。**

## 六阶段流水线

| 阶段 | 做什么 | 产出物 |
|---|---|---|
| 0 预检 | 探测技术栈、定位 theme/token 层、探测截图能力 | 能力报告(哪些能自动、哪些需用户补) |
| 1 抽取 | `get_metadata` 结构 → `get_variable_defs` token → 逐区块 `get_design_context` → `download_assets` 资源 → `get_screenshot` 基准图 | scratchpad 内的设计真值集 |
| 2 token 对账 | Figma 变量 ↔ 项目 theme 建映射;缺失的**先补进 theme 层**;禁止页面内硬编码色值/字号 | `token-map.md` |
| 3 生成 | 按 `references/layout-mapping.md` 的映射表写代码;布局用语义(flex/Row/Column),不用绝对定位 | 页面代码 |
| 4 校验闭环 | 跑起来截图 → `bin/pixdiff.py` 对齐 + 分块偏差排行 → 只针对 top-N 偏差块改 → 重跑 | 每轮一个偏差数字 |
| 5 收尾 | 还原度、残留偏差清单、交互/动效 TODO,提示 `/clear` | 报告 |

### 阶段 4 是核心

`pixdiff.py` 把画面切网格,输出**按偏差排序的区块清单**。模型因此不是盯整张图找差异,而是拿到一份有序待修清单。

收敛条件(满足任一即停):

- 整体差异 ≤ 1% → 通过
- 连续两轮无改善 → 停止,**如实报告残留偏差**,不假装完成
- 达到最大轮次(默认 5)→ 同上

### 上下文纪律

图片一旦读入即常驻整轮上下文。因此:

- 一轮只做一个 frame,阶段 5 主动提示 `/clear`
- `references/layout-mapping.md` 单独拆文件,仅阶段 3 按需读取,不常驻
- 大页面先 `get_metadata` 定位,再逐区块深挖,不一次性拉全树

## 文件结构

```
skills/figma-to-page/
├── SKILL.md                      # 主流程 + 硬性 checklist
├── README.md                     # 合集规范 badge README
├── bin/
│   ├── pixdiff.py                # 像素 diff + 分块偏差排行
│   └── detect-stack.sh           # 栈 / token 层 / 截图能力探测
├── references/
│   └── layout-mapping.md         # Figma → Flutter/CSS 映射表 + 高频坑
└── tests/run.sh                  # 离线测试
```

## 测试策略

`tests/run.sh` 全离线、零网络:

- 合成已知偏差的图片对,断言 `pixdiff.py` 的差异百分比、分块排行顺序、阈值退出码
- 断言尺寸不一致时的对齐行为与拒绝条件
- 造假项目目录(pubspec.yaml / package.json / tailwind.config.js),断言 `detect-stack.sh` 判栈与 token 层定位正确
- Pillow 缺失时断言优雅降级而非崩溃

CI 另有两道:`skill-doctor` lint、`check-readme-sync.sh`(需同步 `README.md` 与 `README.zh-CN.md`)。

## 修订 1(2026-08-13,实现中发现)

核对 Figma MCP 工具契约与 `figma/docs/rate-limits-access.md` 后,发现三个必须修正的点:

### 1. MCP 读取类工具有硬配额 —— 原设计不可用

| Seat | Starter | Professional | Organization | Enterprise |
|---|---|---|---|---|
| View / Collab | 20 **/月** | 6 /月 | 6 /月 | 6 /月 |
| Dev / Full | 20 /月 | 200 /天 | 200 /天 | 600 /天 |

豁免:`whoami`、`generate_figma_design`、`add_code_connect_map`。

原阶段 1 每帧消耗 7–9 次调用(metadata + variable_defs + code_connect + design_context×N + assets + screenshot)。**Starter + View seat 每月 20 次 → 每月仅能做 2 个页面**,等于不可用。

**修正:**

- 新增 `bin/figma-cache.sh`,把**文件级**数据(`get_variable_defs`、`get_code_connect_map`)落盘缓存,按 fileKey 跨帧跨会话复用,默认 30 天过期
- 拆出「省调用模式」(默认):每帧 2–3 次,跳过 `get_metadata`,`download_assets` 仅在确有图标时调
- 「完整模式」保留给配额充裕场景。**省上下文与省配额此消彼长**,按实际瓶颈选,不是单纯的优劣关系
- 阶段 0 用 `whoami`(免费)确认 seat,并把本次预计消耗告知用户

效果:首帧 4–5 次、后续 2–3 次 → 每月 6–8 个页面。

### 2. `get_screenshot` 默认返回 URL + curl 指令,不是内联图片

这是**好消息**:阶段 4 的闭环成立(curl 落盘给 `pixdiff.py`),且比内联省大量上下文。

- **禁止设 `enableBase64Response: true`** —— 既吃上下文,又给不出 pixdiff 需要的磁盘路径。仅在无 shell 环境才用
- 资源 URL 均为短时效,须立刻 curl

### 3. `maxDimension` 默认 1024 会降采样

默认把长边压到 1024。桌面端 1440 宽的稿子会被缩小,拿它当像素比对基准就失准。响应含 `original_width`/`original_height`,须按原始尺寸显式设置。

## 可选人工旁路

结构刁钻的 frame(深层嵌套 Auto Layout + 混合约束)可手动跑 FigmaToCode 插件,把其确定性输出粘进来当「参考答案」,由 skill 改写成符合项目 token 与组件规范的版本。**旁路而非必经路径。**
