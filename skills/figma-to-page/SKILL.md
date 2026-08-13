---
name: figma-to-page
description: 按 Figma 设计稿还原页面代码,拉结构化设计数据 + design token,写完用像素 diff 自校验迭代到还原。当用户给出 figma.com 链接要实现页面、或说「照设计稿写这个页面 / 还原设计图 / 这个页面和设计稿对不上 / 按 Figma 做 UI / 设计稿还原度不够」时触发。
---

# figma-to-page — 设计稿一次还原

> **核心判断:还原度差不是「模型不会写样式」,而是「输入信息量不足 + 没有闭环校验」。**
> 本 skill 只做静态视觉还原,不做交互与动效。

## 何时触发

用户说:

- 「照这个 Figma 稿把页面写出来」/ 给出 `figma.com/design/...?node-id=...` 链接
- 「还原一下这个设计图」/「按设计稿做这个页面」
- 「做出来跟设计稿对不上 / 还原度不够 / 差挺多」

## 四条铁律

1. **不看截图猜数值。** 间距、字号、行高、色值一律从 `get_design_context` / `get_variable_defs` 取真值。截图只用于最后对答案。
2. **不硬编码样式值。** 所有色值 / 字号 / 间距必须走项目的 token / theme 层;项目没有就先建一个(阶段 2)。
3. **不靠肉眼说「差不多」收工。** 必须跑 `bin/pixdiff.py` 拿到量化偏差,收敛到阈值或如实报告残留。
4. **不浪费 MCP 配额。** Figma 读取类工具有**月/日配额**,见下。每一次调用都要有明确理由。

## ⚠️ MCP 配额纪律

Figma MCP 的**读取类工具有硬配额**,按 plan + seat 计:

| Seat | Starter | Professional | Organization | Enterprise |
|---|---|---|---|---|
| View / Collab | 20 **/月** | 6 /月 | 6 /月 | 6 /月 |
| Dev / Full | 20 /月 | 200 /天 | 200 /天 | 600 /天 |

豁免(不计配额):`whoami`、`generate_figma_design`、`add_code_connect_map`。

**View seat 用户一个月只有 20 次。** 因此:

- **阶段 0 先用 `whoami`(免费)确认 seat**,再按配额决定走「省调用模式」还是「完整模式」。
- **文件级数据必须缓存复用** —— `get_variable_defs`、`get_code_connect_map` 是整个设计文件的属性,不随页面变化,用 `bin/figma-cache.sh` 存盘,同一文件只付一次。
- **每次调用前先想:这次调用换来的信息,是不是已经在手上了。**
- 开工前**把预计消耗告诉用户**(例:「本次预计 3 次调用,其中 token 定义走缓存」)。

## 阶段 0 · 预检

```bash
bash <skill>/bin/detect-stack.sh <项目根目录>
bash <skill>/bin/figma-cache.sh list          # 看哪些文件级数据已有缓存
```

再调 `whoami`(**不计配额**)确认 seat 与 plan。

输出技术栈、token 层候选位置、可用截图手段、Pillow 是否可用。**把这份能力报告告诉用户**,特别是需要降级的部分(没有 token 层 / 没有自动截图手段 / 缺 Pillow),以及**本次预计的 MCP 调用次数**。不要静默跳过任何一项。

同时确认链接是否带 `node-id`。**没有 node-id 就是整个文件而非具体 frame** —— 要求用户在 Figma 里选中目标 frame 再复制链接。链接里 `figma.com/design/<fileKey>/<名字>?node-id=1-2` → `fileKey` 与 `nodeId=1:2`。

> 别在没有 node-id 的情况下猜一个 —— 工具会拒绝,白烧一次配额。

## 阶段 1 · 抽取设计真值

Figma MCP 工具名的前缀随客户端而变(如 `mcp__claude_ai_Figma__get_design_context`),按实际可用的工具名调用。

### 省调用模式(默认,配额 ≤ 50 次/月时必用)

**每帧 2–3 次调用。** 首次接触某个设计文件时额外 +2(之后走缓存)。

| 步骤 | 工具 | 计费 | 说明 |
|---|---|---|---|
| 1.1 | `get_design_context` | 1 | **直接拉整个 frame**,不先 `get_metadata`。拿 layout / 文本 / 填充 / 圆角 / 描边真值 |
| 1.2 | `get_screenshot` | 1 | 基准图,详见下方「截图落盘」 |
| 1.3 | `download_assets` | 0–1 | **仅当 frame 里确有图标/图片时**调用;纯文字卡片布局跳过 |
| 1.4 | `get_variable_defs` | 0–1 | **先查缓存**,未命中才调,调完立刻写缓存 |
| 1.5 | `get_code_connect_map` | 0–1 | 同上。项目没配 Code Connect 就永久跳过 |

缓存用法:

```bash
# 先查(命中则省一次调用)
bash <skill>/bin/figma-cache.sh get <fileKey> variables && echo 命中
# 未命中 → 调 get_variable_defs → 把结果写盘
bash <skill>/bin/figma-cache.sh put <fileKey> variables <结果文件>
```

### 完整模式(配额充裕时,如 Dev seat 200 次/天)

在省调用模式前面加一步 `get_metadata` 拿轻量节点索引,再按结构**分区块**多次 `get_design_context`。大 frame 这样更精确、也更省**上下文**,但更费**配额** —— 两者是此消彼长的,按实际瓶颈选。

### 截图落盘(阶段 4 的闭环依赖这步)

`get_screenshot` 默认返回**短时效 URL + curl 指令**,不是内联图片。照它给的 curl 存到 scratchpad:

```bash
curl -sL "<返回的URL>" -o <scratchpad>/design-baseline.png
```

三条硬性要求:

- **不要设 `enableBase64Response: true`。** 内联 base64 会吃掉大量上下文,而且 `pixdiff.py` 需要的是磁盘文件路径。只有在完全没有 shell 的环境才用它。
- **显式设 `maxDimension`。** 默认值 **1024** 会把长边压到 1024,桌面端稿子(如 1440 宽)会被降采样,拿它当像素比对基准就失准了。响应的 JSON 里有 `original_width` / `original_height`,按节点原始尺寸设置;若发现返回的 `width`/`height` 小于 original,按 original 重取一次。
- **URL 是短时效的,立刻 curl。** `download_assets` 返回的资源 URL 同理(且 raw images 与 svg 各上限 20 个)。

## 阶段 2 · token 对账

1. 把 1.2 拿到的 Figma 变量与阶段 0 定位的项目 token 层逐项比对,产出 `token-map.md`(scratchpad 里),三列:Figma 变量名 → 项目 token → 状态(已有 / 新增)。
2. **缺失的 token 先补进 theme 层**,再写页面。
3. 项目根本没有 token 层时:**主动建一个**(Flutter → `AppColors`/`AppTextStyles`/`AppSpacing` + `ThemeData`;Web → CSS 变量或 tailwind theme)。建之前**告诉用户你要新建哪些文件**。
4. 命名跟随 Figma 变量语义,不要按具体色值命名(`AppColors.textSecondary` 而非 `AppColors.gray666`)。

这一步的产出是**地基**。跳过它,后面每个页面都会重新长出一套硬编码值。

## 阶段 3 · 生成代码

写代码前读映射表(**只在这一步读,不要提前载入**):

```
<skill>/references/layout-mapping.md
```

硬性要求:

- **Auto Layout 译成布局语义,不是绝对定位。** `space-between` → `MainAxisAlignment.spaceBetween` / `justify-between`,不是算出 137px 的 `SizedBox`。绝对定位只在 Figma 里确实是非 Auto Layout 容器时才用。
- **行高必须换算。** Figma 的 `lineHeight` 有 PIXELS / PERCENT / AUTO 三种单位,Flutter 的 `TextStyle.height` 是**倍数**。这是最高频的隐形偏差来源,细则见映射表。
- **HUG / FILL / FIXED 三种 sizing 分别对应不同写法**,不要一律给死宽高。
- 遵循项目既有的组件与代码风格;1.3 命中的组件直接复用。

## 阶段 4 · 校验闭环(核心)

这一步决定「一次还原」能不能成立。**不允许跳过。**

```bash
# 1) 把页面跑起来并截图(按阶段 0 探测到的手段,从上往下试)
# 2) 比对
python3 <skill>/bin/pixdiff.py \
  --design <阶段1.6的基准图> \
  --actual <实现截图> \
  --threshold 1.0 \
  --out-dir <scratchpad>/diffout
```

脚本会输出:整体偏差百分比 + **按缺陷聚合并排序的待修清单** + 三张图(热力图 / 红框标注图 / 并排图)。

迭代规则:

1. 读 `diff-annotated.png` 和待修清单,**从 #1 开始修**。一个簇是一个缺陷,不要把同一簇当成多个问题。
2. 改完重新截图、重跑脚本。
3. 收敛判定(满足任一即停):
   - 偏差 ≤ 1%(退出码 0)→ **通过**
   - **连续两轮偏差无改善** → 停止,如实报告残留偏差
   - 达到 5 轮 → 同上
4. **绝不假装收敛。** 没到阈值就明说当前偏差是多少、卡在哪。

截图前先确认比对条件一致:**同一设备尺寸、同一滚动位置、同样有无状态栏**。脚本报「长宽比不一致」时,先修截图范围,再看偏差数字 —— 此时的数字没有意义。

缺 Pillow 时降级:把基准图与实现截图并排交给自己做肉眼对比,列出可测量偏差(padding 差几 px、字号差几号、色值差一档)。**必须告知用户这一轮没有量化阈值。**

## 阶段 5 · 收尾

报告三件事:

1. 最终还原度(偏差百分比)与是否达标
2. 残留偏差清单(如有)—— 具体位置 + 原因 + 建议
3. 交互 / 动效 / 响应式 TODO(本 skill 不做的部分)

然后**提示用户 `/clear`**:图片一旦读入即常驻整轮上下文,一个会话连做多个 frame 会明显变慢变贵。

## 上下文纪律

- **一轮只做一个 frame。** 多个页面分多轮,每轮之间 `/clear`。
- 同一张图**只读一次**,读过就记住,不要回头重读。
- 大 frame 在**完整模式**下先 `get_metadata` 定位再分区块拉;**省调用模式下不这么做** —— 省上下文与省配额此消彼长,配额紧时优先省配额。
- 截图走 URL + curl 落盘,**不要内联 base64**(既吃上下文又不能给 pixdiff 用)。
- `references/layout-mapping.md` 只在阶段 3 读。

## 可选人工旁路

遇到结构特别刁钻的 frame(深层嵌套 Auto Layout + 混合约束),可以让用户手动跑一下 [FigmaToCode](https://github.com/bernaferrari/FigmaToCode) 插件,把它的确定性输出粘进来当「参考答案」,你负责改写成符合项目 token 与组件规范的版本。

这是旁路,不是必经路径 —— 该插件产出的是独立 scaffold,会绕过项目的 theme 层和现有组件,**不能直接采用**。

## 常见失败模式

| 现象 | 真实原因 | 对策 |
|---|---|---|
| 间距处处差几像素 | 用截图目测而非 `get_design_context` | 回阶段 1 拉真值 |
| 文字位置整体偏移 | 行高单位没换算 | 见映射表的行高小节 |
| 换个机型就崩 | 用绝对定位代替 Auto Layout | 回阶段 3 改布局语义 |
| 偏差数字大得离谱(>50%) | 截图范围不对(滚动位置 / 状态栏 / 裁剪) | 先修截图,再看数字 |
| 同一个颜色在多页面不一致 | 跳过了阶段 2 | 补 token 层 |
| 图标形状不对 | 手写 SVG 近似 | 用 `download_assets` 导出 |
| 基准图比实现图小一圈、细节糊 | `maxDimension` 用了默认 1024 | 按 `original_width/height` 重取 |
| MCP 报配额超限 | 每帧重复拉文件级数据 | 用 `figma-cache.sh` 缓存;或升级 seat |
| 换个屏幕宽度就崩 | `RIGHT`/`STRETCH` 约束被写成固定 left | 见映射表 §5.3 |
