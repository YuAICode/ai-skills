# Figma → 代码 映射表

> **只在阶段 3(生成代码)读这份文件。**
>
> 规则提炼自 [FigmaToCode](https://github.com/bernaferrari/FigmaToCode) 的确定性生成器实现
> (`packages/backend/src` 约 37 个源文件),该项目明确声明「不调用 AI 模型」,
> 所有映射都是硬编码验证过的,因此可以当作可靠基线。
>
> 文中标注「**源码空白**」的条目,指该项目确实没有实现这段逻辑 —— 这些恰恰是**你必须自己处理**的地方。

---

## 1. Auto Layout → 布局语义

### 1.1 主轴方向

| `layoutMode` | Flutter | CSS / Tailwind |
|---|---|---|
| `HORIZONTAL` | `Row` | 默认 flex-row(不必显式加类) |
| `VERTICAL` | `Column` | `flex-col` |
| `NONE` | 无 Row/Column,子节点走 `Stack` + `Positioned` | 不产出 flex 属性,子节点绝对定位 |

`layoutMode` 缺失等价于 `NONE`。

### 1.2 主轴对齐 `primaryAxisAlignItems`

| 值 | Flutter | Tailwind |
|---|---|---|
| 缺省 / `MIN` | `MainAxisAlignment.start` | `justify-start` |
| `CENTER` | `MainAxisAlignment.center` | `justify-center` |
| `MAX` | `MainAxisAlignment.end` | `justify-end` |
| `SPACE_BETWEEN` | `MainAxisAlignment.spaceBetween` | `justify-between` |

### 1.3 交叉轴对齐 `counterAxisAlignItems`

| 值 | Flutter | Tailwind |
|---|---|---|
| 缺省 / `MIN` | `CrossAxisAlignment.start` | `items-start` |
| `CENTER` | `CrossAxisAlignment.center` | `items-center` |
| `MAX` | `CrossAxisAlignment.end` | `items-end` |
| `BASELINE` | `CrossAxisAlignment.baseline` | `items-baseline` |

换行场景下 `counterAxisAlignContent === "SPACE_BETWEEN"` 优先于上表(Flutter → `WrapAlignment.spaceBetween`)。
`layoutWrap === "WRAP"` → Flutter `Wrap`,CSS `flex-wrap`。

### 1.4 间距 `itemSpacing`

- `> 0` 且**不是** `SPACE_BETWEEN` → CSS `gap`;Flutter 用 `Row/Column` 的 `spacing` 参数或在子项间插 `SizedBox`。
- 已经是 `SPACE_BETWEEN` → **不要再加 gap**,否则两套间距叠加。

### 1.5 内边距 padding

四个值先做塌缩,再选写法:

| 条件 | Flutter | CSS |
|---|---|---|
| 四值相同 | `EdgeInsets.all(x)` | `p-*` |
| 左右相同 且 上下相同 | `EdgeInsets.symmetric(horizontal:, vertical:)` | `px-* py-*` |
| 其余 | `EdgeInsets.only(...)` | `pl-* pr-* pt-* pb-*` |

padding 缺失按 0 处理。数值保留两位小数后去掉多余零。

---

## 2. 文本

### 2.1 行高 —— 最高频的隐形偏差来源

Figma 的 `lineHeight` 有**三种单位**,必须先看 `unit` 再换算:

| `lineHeight.unit` | 像素值(CSS 用) | Flutter `TextStyle.height`(**倍数**) |
|---|---|---|
| `PIXELS` | `value` | `value / fontSize` |
| `PERCENT` | `fontSize * value / 100` | `value / 100` |
| `AUTO` | 不设置 | **不输出 `height`**(不要写 1.0) |

例:`fontSize: 16`、`lineHeight: {unit: PERCENT, value: 150}` → CSS `line-height: 24px`;Flutter `height: 1.5`。

> `AUTO` 时显式写 `height: 1.0` 是错的 —— 它会压掉字体自带的行高,导致整段文字位置上移。

### 2.2 字间距 `letterSpacing`

| 单位 | 换算 |
|---|---|
| `PIXELS` | 原值 |
| `PERCENT` | `fontSize * value / 100` |

### 2.3 字重

| Figma 名称 | 数值 | Figma 名称 | 数值 |
|---|---|---|---|
| thin | 100 | semibold | 600 |
| extralight | 200 | bold | 700 |
| light | 300 | extrabold | 800 |
| regular | 400 | heavy | 800 |
| medium | 500 | black | 900 |

无法匹配 → `400`。Flutter `FontWeight.w{n}`,Tailwind `font-{n}`。

### 2.4 对齐与截断

- 水平对齐:`LEFT` 是默认值,**不必输出**;其余 → Flutter `TextAlign.*` / CSS `text-center|right|justify`。
- 多行截断:`textTruncation !== "DISABLED"` 时生效。CSS `line-clamp-{maxLines}`;Flutter 用 `maxLines` + `overflow: TextOverflow.ellipsis`(**FigmaToCode 未实现 Flutter 侧截断,需你自己写**)。

---

## 3. 颜色与填充

### 3.1 纯色

- `alpha === 1` → 6 位 hex(大写)
- `alpha < 1` → `rgba(r,g,b,a)`;Flutter 用 `Color(0xAARRGGBB)` 或 `.withOpacity()`
- 通道值是 0..1 浮点,需 `× 255` 取整

### 3.2 多层填充 ⚠️

`fills` 是**数组**,索引 0 是最底层。渲染顺序需 `reverse()`。

- CSS 支持多背景:逐层映射后逗号拼接
- Flutter 单个 `Container` 只能一层背景 → 多层填充需嵌套 `Container` 或用 `Stack`

**不要只取最上层就完事** —— FigmaToCode 的取色板路径就是只取最上层(`retrieveTopFill`),会静默丢弃其余图层。

### 3.3 渐变

| 类型 | CSS | 说明 |
|---|---|---|
| 线性 | `linear-gradient` | 角度由 `gradientTransform` 经 `atan2` 反算 |
| 径向 | `radial-gradient` | 需算圆心 + 两个半径 handle 的百分比 |
| 角度 | `conic-gradient(from {a}deg at {cx}% {cy}%)` | — |
| 菱形 | **无原生 CSS 等价** | 只能用四个方向线性渐变分区拼接**近似**,必须肉眼校验 |

色标位置 → `${(position * 100).toFixed(0)}%`。

### 3.4 混合模式

`PASS_THROUGH` 归一化为 `normal`;`NORMAL` 不输出。其余值转小写直接给 CSS —— **注意 Figma 的命名与 CSS 关键字并非全部对应**,不支持的值会被浏览器静默忽略,需人工核对。

---

## 4. 圆角、描边、阴影

### 4.1 圆角

读取优先级:`rectangleCornerRadii` 数组 → 单值 `cornerRadius`(注意排除 `figma.mixed`)→ 四个独立属性。

- 四角相等 → 单一属性
- 不等 → 四个独立属性,**只输出非零角**
- 椭圆节点 → `border-radius: 9999px`
- `clipsContent === true` 且有子节点 → 附加 `overflow: hidden` / Flutter `ClipRRect`

Tailwind 刻度(rem):`0→none, 0.125→sm, 0.25→rounded, 0.375→md, 0.5→lg, 0.75→xl, 1.0→2xl, 1.5→3xl, 10→full`

### 4.2 描边 —— 平台差异陷阱 ⚠️

`strokeWeight` 四边相等则单值,否则四个独立值。

`strokeAlign` 的处理**两个平台根本不同**:

| `strokeAlign` | Flutter | CSS |
|---|---|---|
| `INSIDE` | `BorderSide(strokeAlign: strokeAlignInside)` | 标准 `border` |
| `CENTER` / `OUTSIDE` | 原生支持,直接传参 | **无原生等价**,只能用 `outline` + `outline-offset` 模拟 |

**关键差异:`outline` 不占布局空间,`border` 占。** 用 outline 模拟外描边时,盒模型尺寸会与设计稿差 `2 × strokeWeight`。这是像素 diff 里"边框附近一圈偏差"的常见原因。

### 4.3 阴影

| Figma 类型 | CSS | Flutter |
|---|---|---|
| `DROP_SHADOW` | `box-shadow` | `BoxShadow`(color / blurRadius / offset / spreadRadius) |
| `INNER_SHADOW` | `box-shadow` + `inset` | **`BoxShadow` 无法表达内阴影** |
| `LAYER_BLUR` | 用 radius 填充,x/y/spread 退化 | — |

**Flutter 遇到 `INNER_SHADOW` 必须自己处理**(嵌套装饰、`ShaderMask` 或 `CustomPainter`)。FigmaToCode 直接丢弃它,不要以为工具替你做了。

多个阴影:CSS 逗号拼接;Flutter `boxShadow` 传数组。

---

## 5. 尺寸与约束

### 5.1 FIXED / HUG / FILL

| `layoutSizing*` | 含义 | Flutter | CSS |
|---|---|---|---|
| `FIXED` | 固定值 | `SizedBox(width/height:)` | 具体 px |
| `HUG` | 按内容撑开 | 不设尺寸,交给内容 | 不设尺寸(或 `w-fit`) |
| `FILL` | 撑满父容器 | 见下 | 见下 |

`FILL` 的写法**取决于父容器**:

| 父容器 | Flutter | CSS |
|---|---|---|
| 是同方向的 Row/Column/flex | 包一层 `Expanded` | `flex: 1 1 0` |
| 不是 | `width/height: double.infinity` | 有 max 约束则 `width:100%`,否则 `align-self: stretch` |

`minWidth/maxWidth` 等 → Flutter 单独生成 `BoxConstraints`,CSS 用 `min-width`/`max-width`。

**特例:`HUG` 但没有子节点 → 按 `FIXED` 处理。** 空的 HUG 容器(占位符、骨架屏)必须给显式尺寸,否则会塌成 0。

### 5.2 layoutGrow / layoutAlign

伸展意图统一从 `layoutSizingHorizontal/Vertical === FILL` 判断,**不要去读 `layoutGrow` 的数值**。FigmaToCode 没有为 `layoutGrow` / `layoutAlign` 写独立映射,一切收敛到 sizing 抽象。

### 5.3 constraints —— 源码空白,必须你自己处理 ⚠️

非 Auto Layout 容器里的子节点带 `constraints`(`LEFT` / `RIGHT` / `CENTER` / `SCALE` / `STRETCH`),表达的是**响应式定位意图**。

**FigmaToCode 完全没有实现这部分**(`commonPosition.ts` 里没有任何 `node.constraints` 分支,经反复核实是源码空白而非未读到)。它只做父子包围盒的相对坐标计算,结果是一律退化成固定 `left/top` 死坐标。

你必须自己译:

| `constraints` | 含义 | 写法 |
|---|---|---|
| `LEFT` / `TOP` | 贴左 / 贴上 | `left:` / `top:` 固定 |
| `RIGHT` / `BOTTOM` | 贴右 / 贴下 | `right:` / `bottom:` 固定(**不是** 换算成 left) |
| `CENTER` | 居中 | `left: 50%` + `translateX(-50%)` / Flutter `Align(center)` |
| `SCALE` | 按比例缩放 | 百分比宽高 |
| `STRETCH` | 两端拉伸 | 同时设 `left` 与 `right` / `top` 与 `bottom` |

**把 `RIGHT` 约束写成固定 `left` 是"换个屏幕宽度就崩"的头号原因。**

### 5.4 什么时候才允许绝对定位

只有两种情况:

1. 节点自身 `layoutPositioning === "ABSOLUTE"`
2. 父节点 `layoutMode === "NONE"`(含父节点没有该属性)

此时 Flutter 用 `Stack` + `Positioned`,CSS 用 `position: absolute`。

**其他任何情况都不要用绝对定位。** 父容器是 Auto Layout 却用绝对定位,是"换机型就崩"的第二大原因。

另:同一父容器内既有 ABSOLUTE 又有普通子节点时,需按 z-index 分离排序;`layoutMode === "NONE"` 时不做这个重排。

---

## 6. 高频坑速查

| # | 现象 | 原因 | 做法 |
|---|---|---|---|
| 1 | 整段文字位置偏移 | 行高单位没换算,或 `AUTO` 时硬写了 `height: 1.0` | 见 §2.1 |
| 2 | 换个屏幕宽度就崩 | `RIGHT`/`STRETCH` 约束被写成固定 left | 见 §5.3 |
| 3 | 换机型就崩 | Auto Layout 容器用了绝对定位 | 见 §5.4 |
| 4 | 边框附近一圈偏差 | CSS 用 `outline` 模拟外描边,不占布局空间 | 见 §4.2 |
| 5 | 内阴影没了(Flutter) | `BoxShadow` 表达不了 inset | 见 §4.3 |
| 6 | 背景少了一层 | 只取了 `fills` 最上层 | 见 §3.2 |
| 7 | 空容器塌成 0 | `HUG` 且无子节点 | 按 FIXED 给显式尺寸,见 §5.1 |
| 8 | 间距是设计稿两倍 | `SPACE_BETWEEN` 之外又加了 gap | 见 §1.4 |
| 9 | 渐变对不上 | 菱形渐变无原生 CSS,只能近似 | 见 §3.3,须肉眼校验 |
| 10 | 混合模式无效 | Figma 命名与 CSS 关键字不全对应 | 见 §3.4 |
| 11 | 图标形状不对 | 手写 SVG 近似 | 回阶段 1 用 `download_assets` 导出 |

---

## 7. 依据强度

- **依据充分**(读到具体映射代码 / switch 分支 / 数值刻度表,且交叉核对了 Flutter 与 HTML/Tailwind 两条路径):§1 Auto Layout、§2 文本、§4 圆角描边阴影、§5 尺寸
- **部分充分**:§3 颜色填充 —— 纯色/透明度/线性渐变充分;混合模式的完整降级规则、图片填充在多层混合中的处理只读到片段
- **经核实的源码空白**:§5.3 constraints —— FigmaToCode 确实没有这段逻辑

源文件清单见 [FigmaToCode 仓库](https://github.com/bernaferrari/FigmaToCode/tree/main/packages/backend/src),重点:
`altNodes/jsonNodeConversion.ts`、`common/commonTextHeightSpacing.ts`、`common/commonPosition.ts`、
`common/nodeWidthHeight.ts`、`common/convertFontWeight.ts`、`flutter/builderImpl/flutterSize.ts`、
`flutter/builderImpl/flutterBorder.ts`、`flutter/builderImpl/flutterShadow.ts`、
`tailwind/conversionTables.ts`、`html/builderImpl/htmlColor.ts`、`html/builderImpl/htmlSize.ts`
