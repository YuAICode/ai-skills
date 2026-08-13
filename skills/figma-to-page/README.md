# figma-to-page

[![Repo](https://img.shields.io/badge/GitHub-YuAICode%2Fai--skills-181717?logo=github)](https://github.com/YuAICode/ai-skills/tree/main/skills/figma-to-page)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../../LICENSE)

按 Figma 设计稿还原页面代码,并用**像素级 diff 自校验**迭代到还原。跨技术栈(Flutter / React / Next / Vue / Svelte / iOS 原生 / 静态 HTML)。

> **为什么需要它:** 设计稿还原度差,根因通常不是「模型不会写样式」,而是 ① 只喂了一张截图,间距字号色值全靠目测;② 写完凭肉眼说「差不多」就收工,偏差无法量化也就无法收敛;③ 没有 token 层,同一个灰色在三个页面出现三个值。

## 安装

```bash
cp -r figma-to-page ~/.claude/skills/
```

依赖:

- **Figma MCP**(必需)—— 官方 Figma MCP server,提供 `get_design_context` / `get_variable_defs` / `download_assets` 等工具
- **Pillow**(可选,强烈建议)—— 像素 diff 用;缺失时自动降级为模型肉眼对比

```bash
python3 -m pip install Pillow
```

## 用法

在对话中给出带 `node-id` 的 Figma 链接:

```
照这个设计稿写页面:https://www.figma.com/design/xxx/yyy?node-id=123-456
```

或说「还原一下这个设计图 / 按 Figma 做这个页面 / 做出来跟设计稿对不上」。

> **务必选中目标 frame 再复制链接。** 不带 `node-id` 的链接指向整个文件,skill 无法定位要还原哪个页面。

## ⚠️ 先看 MCP 配额

Figma MCP 的**读取类工具有硬配额**,按 plan + seat 计:

| Seat | Starter | Professional | Organization | Enterprise |
|---|---|---|---|---|
| View / Collab | 20 **/月** | 6 /月 | 6 /月 | 6 /月 |
| Dev / Full | 20 /月 | 200 /天 | 200 /天 | 600 /天 |

豁免(不计配额):`whoami`、`generate_figma_design`、`add_code_connect_map`。

**View seat 一个月只有 20 次**,因此 skill 默认走**省调用模式**:每帧 2–3 次调用,文件级数据(design variables、Code Connect 映射)用 `bin/figma-cache.sh` 落盘缓存跨帧复用。首帧 4–5 次、后续帧 2–3 次,约合**每月 6–8 个页面**。

配额充裕时(Dev/Full seat)可切**完整模式**:先 `get_metadata` 拿结构再分区块拉 `get_design_context`,更精确、更省上下文,但更费配额 —— 两者此消彼长,按实际瓶颈选。

用 `whoami`(不计配额)确认自己的 seat。

## 六阶段流程

| 阶段 | 做什么 | 产出 |
|---|---|---|
| 0 预检 | 探测技术栈、token 层位置、可用截图手段 | 能力报告(含需降级项) |
| 1 抽取 | `get_metadata` → `get_variable_defs` → `get_code_connect_map` → `get_design_context` → `download_assets` → `get_screenshot` | 设计真值集 + 基准图 |
| 2 token 对账 | Figma 变量 ↔ 项目 theme 映射,缺的补进去;没有 token 层就建 | `token-map.md` |
| 3 生成 | 按映射表写代码,布局用语义而非绝对定位 | 页面代码 |
| 4 校验闭环 | 截图 → `pixdiff.py` → 按缺陷簇修 → 重跑 | 每轮一个偏差数字 |
| 5 收尾 | 还原度 / 残留偏差 / 交互 TODO,提示 `/clear` | 报告 |

## 脚本

### `bin/detect-stack.sh`

```bash
bash bin/detect-stack.sh [项目根目录]
```

启发式探测技术栈、design token 层候选位置、可用截图手段、Pillow 可用性。退出码 `0`=完成探测(信息性),`1`=目录无效。

### `bin/figma-cache.sh`

把**文件级**的 Figma 数据(design variables、Code Connect 映射)缓存到磁盘,跨 frame、跨会话复用 —— 这类数据不随页面变化,每帧重拉纯属浪费配额。

```bash
bash bin/figma-cache.sh path  <fileKey> <kind>            # 打印缓存路径
bash bin/figma-cache.sh get   <fileKey> <kind> [最大天数]  # 命中输出内容 exit 0;未命中/过期 exit 1
bash bin/figma-cache.sh put   <fileKey> <kind> <源文件|->  # 写入(- 表示读 stdin)
bash bin/figma-cache.sh list                              # 列出所有缓存及年龄
bash bin/figma-cache.sh clear [fileKey]                   # 清除全部或指定文件
```

`kind` ∈ `variables` | `codeconnect`。缓存目录 `${XDG_CACHE_HOME:-~/.cache}/figma-to-page/`,默认 30 天过期(token 会变,过期就重拉)。

退出码:`0`=成功/命中 / `1`=未命中或过期 / `2`=用法错误。

设计细节:空内容不写缓存(否则后续会命中一个空结果);`fileKey` 只允许字母数字(防路径穿越);`kind` 白名单校验(拼错导致的静默永不命中比报错更难查)。

### `bin/pixdiff.py`

```bash
python3 bin/pixdiff.py --design <设计稿.png> --actual <实现截图.png> \
  [--threshold 1.0] [--tol 12] [--grid 12] [--top 8] \
  [--cluster-floor 2.0] [--out-dir DIR] [--json]
```

| 参数 | 说明 | 默认 |
|---|---|---|
| `--threshold` | 通过阈值(偏差像素占比 %) | `1.0` |
| `--tol` | 单像素容差:通道最大差值 > N 才算偏差,滤抗锯齿噪声 | `12` |
| `--grid` | 横向切分列数(纵向按比例,尽量方块) | `12` |
| `--top` | 输出偏差最大的 N 个缺陷簇 | `8` |
| `--cluster-floor` | 区块偏差超过该 % 才参与聚合 | `2.0` |
| `--out-dir` | 产出热力图 / 标注图 / 并排图 | 不产图 |
| `--json` | 机器可解析输出 | 人类可读 |

退出码:`0`=通过 / `2`=超阈值 / `1`=输入或参数错误 / `3`=缺 Pillow(**调用方应降级,不是失败**)。

**关键设计:缺陷簇聚合。** 一个真实缺陷(如按钮整体下移 8px)会横跨多个相邻网格。若直接按区块排行,top-N 会被同一个缺陷占满,模型误以为有 N 个独立问题。脚本用 4 邻域连通把相邻偏差区块并成一个缺陷簇,按偏差像素总量排序 —— top-N 因此是 N 个**不同**的缺陷。

### 输出示例

```
[pixdiff] 设计稿还原度对比
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠  实现截图已从 780x1688 缩放到设计稿尺寸 390x844 后对比。

尺寸基准    : 390x844
网格        : 26 行 × 12 列
单像素容差  : 通道最大差值 > 12 记为偏差

偏差像素占比: 8.723%   (阈值 1.000%)
平均色差    : 2.184%

待修缺陷(相邻偏差区块已聚合;序号对应 diff-annotated.png 的红框):
  #    区域 (l,t,r,b)             偏差像素数       区内偏差%       平均色差%
  1    0,130,390,260            28712       56.631      14.172

❌ 未通过:偏差 8.723% > 阈值 1.000%
   下一步:按上表从 #1 开始修,改完重新截图再跑本脚本。
   若连续两轮偏差无改善,停止迭代并如实报告残留偏差,不要假装收敛。
```

## 收敛规则

满足任一即停:

- 偏差 ≤ 阈值 → 通过
- **连续两轮无改善** → 停止,如实报告残留偏差
- 达到 5 轮 → 同上

设计上明确**不允许假装收敛**:没到阈值就说清当前偏差和卡点。

## 参考文档

`references/layout-mapping.md` —— Figma 属性(Auto Layout / 文本 / 填充 / 圆角描边阴影 / sizing 约束)→ Flutter 与 CSS 的映射表,以及高频坑清单。规则提炼自 [FigmaToCode](https://github.com/bernaferrari/FigmaToCode) 的确定性生成器实现。

**仅在阶段 3 按需读取**,不常驻上下文。

## 关于两个相关开源项目

| 项目 | 是否使用 | 原因 |
|---|---|---|
| [Figma-Context-MCP](https://github.com/GLips/Figma-Context-MCP) | ❌ 不用 | 能力是官方 Figma MCP 的子集(无 design variables、无资源导出、无 Code Connect),还要额外签 Figma API token |
| [FigmaToCode](https://github.com/bernaferrari/FigmaToCode) | ⚠️ 只提炼规则 | `packages/backend` 是 `private: true` 未发 npm,且依赖 `@figma/plugin-typings`(输入为插件运行时节点,非 MCP JSON);其产物是独立 scaffold,会绕过宿主项目 token 层。作为可选人工旁路使用 |

## 已知局限

- **只做静态视觉还原**,不做交互、动效、响应式断点
- 一轮一个 frame(图片常驻上下文,多 frame 应分多轮 + `/clear`)
- `detect-stack.sh` 是启发式:探不到不等于不存在
- 像素 diff 对**字体渲染差异**敏感(系统字体缺失、字体 hinting 不同会抬高基线偏差);此时应放宽 `--tol` 或改看结构性偏差

## 测试

```bash
bash tests/run.sh
```

69 项断言,全离线、零网络,兼容 macOS 自带 bash 3.2。含 Pillow 缺失时的降级路径验证。

## License

[MIT](../../LICENSE)
