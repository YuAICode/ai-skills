#!/usr/bin/env bash
# figma-to-page 测试:合成已知偏差的图片对,断言 pixdiff 的数值/排行/阈值/退出码;
# 造假项目目录,断言 detect-stack 的判栈与 token 层定位。
# 全离线、零网络。兼容 macOS 自带 bash 3.2(不用 mapfile 等 4.x builtin)。
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIXDIFF="$DIR/../bin/pixdiff.py"
DETECT="$DIR/../bin/detect-stack.sh"
FCACHE="$DIR/../bin/figma-cache.sh"
QMODE="$DIR/../bin/quota-mode.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'

ok()   { printf "${GREEN}  ✓ %s${NC}\n" "$1"; pass=$((pass+1)); }
bad()  { printf "${RED}  ✗ %s${NC}\n" "$1"; fail=$((fail+1)); }

# assert_exit <期望码> <测试名> -- <命令...>
assert_exit() {
  local want="$1" name="$2"; shift 3
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then ok "$name"
  else bad "$name (期望 exit $want,实际 exit $got)"; fi
}

# assert_contains <期望子串> <测试名> -- <命令...>
assert_contains() {
  local want="$1" name="$2"; shift 3
  local out
  out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -qF "$want"; then ok "$name"
  else bad "$name (输出中未找到: $want)"; fi
}

# assert_not_contains <不应出现的子串> <测试名> -- <命令...>
assert_not_contains() {
  local want="$1" name="$2"; shift 3
  local out
  out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -qF "$want"; then bad "$name (输出中意外出现: $want)"
  else ok "$name"; fi
}

# ============================================================
# 前置:python3 与 Pillow
# ============================================================
if ! command -v python3 >/dev/null 2>&1; then
  printf "${YELLOW}跳过全部测试:未找到 python3${NC}\n"
  exit 0
fi

HAS_PILLOW=0
if python3 -c 'import PIL' >/dev/null 2>&1; then HAS_PILLOW=1; fi

# ============================================================
# Pillow 缺失时的优雅降级(退出码 3),用一个假的 PIL 模块遮蔽真实 Pillow
# ============================================================
echo "== pixdiff:Pillow 缺失降级 =="
FAKEPIL="$TMP/fakepil"
mkdir -p "$FAKEPIL"
# 空的 PIL.py:import PIL 成功,但 from PIL import Image 会抛 ImportError
: > "$FAKEPIL/PIL.py"

assert_exit 3 "缺 Pillow 时退出码为 3(而非崩溃)" -- \
  env PYTHONPATH="$FAKEPIL" python3 "$PIXDIFF" --design x.png --actual y.png
assert_contains "降级方案" "缺 Pillow 时输出降级指引" -- \
  env PYTHONPATH="$FAKEPIL" python3 "$PIXDIFF" --design x.png --actual y.png

if [ "$HAS_PILLOW" = "0" ]; then
  printf "${YELLOW}未安装 Pillow,跳过 pixdiff 的图像对比测试(降级路径已验证)${NC}\n"
else

# ============================================================
# 造图工具:生成纯色底图,可在指定矩形涂另一种颜色
# ============================================================
make_img() {
  # make_img <输出路径> <宽> <高> <底色r,g,b> [矩形 l,t,r,b] [矩形色r,g,b]
  python3 - "$@" <<'PY'
import sys
from PIL import Image, ImageDraw
out, w, h, base = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
img = Image.new("RGB", (w, h), tuple(int(x) for x in base.split(",")))
if len(sys.argv) > 6:
    box = [int(x) for x in sys.argv[5].split(",")]
    color = tuple(int(x) for x in sys.argv[6].split(","))
    ImageDraw.Draw(img).rectangle(box, fill=color)
img.save(out)
PY
}

# 取 JSON 里的字段
json_get() {
  # json_get <json文本> <python表达式,d 为已解析对象>
  python3 -c 'import sys,json; d=json.load(sys.stdin); print(eval(sys.argv[1]))' "$2" <<<"$1"
}

BASE="$TMP/design.png"
make_img "$BASE" 200 400 "255,255,255"

# ------------------------------------------------------------
echo "== pixdiff:完全相同的两张图 =="
SAME="$TMP/same.png"
make_img "$SAME" 200 400 "255,255,255"
assert_exit 0 "相同图片通过(exit 0)" -- python3 "$PIXDIFF" --design "$BASE" --actual "$SAME"
assert_contains "偏差像素占比: 0.000%" "相同图片偏差为 0" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$SAME"

# ------------------------------------------------------------
echo "== pixdiff:已知偏差面积与阈值判定 =="
# 200x400 = 80000 像素;涂 40x40=1600 像素 = 2.0%
DIFF2="$TMP/diff2pct.png"
make_img "$DIFF2" 200 400 "255,255,255" "0,0,39,39" "0,0,0"

OUT="$(python3 "$PIXDIFF" --design "$BASE" --actual "$DIFF2" --json 2>&1)"
GOT_PCT="$(json_get "$OUT" 'd["overall_changed_pct"]')"
if [ "$GOT_PCT" = "2.0" ]; then
  ok "偏差面积计算准确(40x40 于 200x400 → 2.0%)"
else
  bad "偏差面积计算 (期望 2.0,实际 $GOT_PCT)"
fi

assert_exit 2 "2% 偏差 vs 阈值 1% → 未通过(exit 2)" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$DIFF2" --threshold 1.0
assert_exit 0 "2% 偏差 vs 阈值 5% → 通过(exit 0)" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$DIFF2" --threshold 5.0
assert_exit 2 "默认阈值即为 1%(2% 偏差应未通过)" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$DIFF2"

# ------------------------------------------------------------
echo "== pixdiff:分块偏差排行定位正确 =="
# 只在右下角涂色,断言 top1 区块落在右下象限
CORNER="$TMP/corner.png"
make_img "$CORNER" 200 400 "255,255,255" "150,350,199,399" "255,0,0"
OUT="$(python3 "$PIXDIFF" --design "$BASE" --actual "$CORNER" --json --grid 4 2>&1)"
L="$(json_get "$OUT" 'd["blocks"][0]["box"][0]')"
T="$(json_get "$OUT" 'd["blocks"][0]["box"][1]')"
if [ "$L" -ge 100 ] && [ "$T" -ge 200 ]; then
  ok "top1 偏差区块定位到右下象限 (l=$L, t=$T)"
else
  bad "top1 偏差区块定位 (期望 l>=100 且 t>=200,实际 l=$L t=$T)"
fi

# 排行必须按偏差降序
OUT="$(python3 "$PIXDIFF" --design "$BASE" --actual "$CORNER" --json --grid 4 --top 20 2>&1)"
if python3 -c '
import sys, json
d = json.load(sys.stdin)
pcts = [b["changed_pct"] for b in d["blocks"]]
sys.exit(0 if pcts == sorted(pcts, reverse=True) else 1)
' <<<"$OUT"; then
  ok "分块排行按偏差降序"
else
  bad "分块排行未按偏差降序"
fi

# ------------------------------------------------------------
echo "== pixdiff:相邻区块聚合成缺陷簇 =="
# 一条横跨整宽的色带(一个真实缺陷,会横跨多个网格)+ 另一处独立小块
# 期望:聚合成 2 个缺陷簇,而不是一堆相邻区块各占一行
TWO="$TMP/two-defects.png"
make_img "$TWO" 200 400 "255,255,255" "0,100,199,130" "0,0,0"
python3 - "$TWO" <<'PY'
import sys
from PIL import Image, ImageDraw
img = Image.open(sys.argv[1]).convert("RGB")
ImageDraw.Draw(img).rectangle([10, 300, 60, 340], fill=(0, 128, 0))
img.save(sys.argv[1])
PY
OUT="$(python3 "$PIXDIFF" --design "$BASE" --actual "$TWO" --json --grid 4 --top 20 2>&1)"
N_CLUSTER="$(json_get "$OUT" 'd["cluster_total"]')"
if [ "$N_CLUSTER" = "2" ]; then
  ok "两处分离缺陷聚合为 2 个簇(而非多个相邻区块)"
else
  bad "缺陷簇数量 (期望 2,实际 $N_CLUSTER)"
fi

# 横跨整宽的色带,其簇 bbox 应覆盖大部分宽度
W_SPAN="$(json_get "$OUT" 'd["clusters"][0]["box"][2] - d["clusters"][0]["box"][0]')"
if [ "$W_SPAN" -ge 150 ]; then
  ok "横跨型缺陷合并为一个宽 bbox (宽 $W_SPAN)"
else
  bad "横跨型缺陷未正确合并 (bbox 宽 $W_SPAN,期望 >=150)"
fi

# 簇按偏差像素总量降序
if python3 -c '
import sys, json
d = json.load(sys.stdin)
px = [c["changed_px"] for c in d["clusters"]]
sys.exit(0 if px == sorted(px, reverse=True) else 1)
' <<<"$OUT"; then
  ok "缺陷簇按偏差像素总量降序"
else
  bad "缺陷簇未按偏差像素总量降序"
fi

# cluster-floor 调高应滤掉噪声簇
NOISE="$TMP/noise.png"
make_img "$NOISE" 200 400 "255,255,255" "0,0,4,4" "0,0,0"
OUT_N="$(python3 "$PIXDIFF" --design "$BASE" --actual "$NOISE" --json --grid 4 --cluster-floor 50 2>&1)"
if [ "$(json_get "$OUT_N" 'd["cluster_total"]')" = "0" ]; then
  ok "--cluster-floor 提高后滤掉微小噪声簇"
else
  bad "--cluster-floor 未滤掉微小噪声簇"
fi

assert_contains "待修缺陷" "报告以缺陷簇形式呈现" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$TWO"

# ------------------------------------------------------------
echo "== pixdiff:单像素容差 tol =="
# 底 255,255,255 vs 245,245,245 → 差值 10
NEAR="$TMP/near.png"
make_img "$NEAR" 200 400 "245,245,245"
assert_exit 0 "色差 10 在默认 tol=12 内 → 视为无偏差" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$NEAR"
assert_exit 2 "同一对图 tol=5 时 → 判为全图偏差" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$NEAR" --tol 5

# ------------------------------------------------------------
echo "== pixdiff:尺寸不一致的对齐与告警 =="
# 等比 2 倍(模拟 DPR=2 截图):应缩放后判为通过,并给出缩放提示
BIG="$TMP/big.png"
make_img "$BIG" 400 800 "255,255,255"
assert_exit 0 "等比放大 2 倍的截图缩放后通过" -- python3 "$PIXDIFF" --design "$BASE" --actual "$BIG"
assert_contains "已从 400x800 缩放到设计稿尺寸 200x400" "输出缩放提示" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$BIG"
assert_not_contains "长宽比不一致" "等比缩放不误报长宽比告警" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$BIG"

# 长宽比明显不同(截错区域):必须告警
WRONG="$TMP/wrong-aspect.png"
make_img "$WRONG" 400 500 "255,255,255"
assert_contains "长宽比不一致" "长宽比差异 >5% 时告警" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$WRONG"
assert_contains "很可能截图区域不对" "告警含排查方向" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$WRONG"

# ------------------------------------------------------------
echo "== pixdiff:透明通道合成到白底 =="
python3 - "$TMP/alpha.png" <<'PY'
import sys
from PIL import Image
# 全透明图:若被当成黑色处理,与白底设计稿会判为 100% 偏差
Image.new("RGBA", (200, 400), (0, 0, 0, 0)).save(sys.argv[1])
PY
assert_exit 0 "全透明 PNG 合成白底后与白底设计稿一致" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$TMP/alpha.png"

# ------------------------------------------------------------
echo "== pixdiff:产图 =="
OUTDIR="$TMP/out"
python3 "$PIXDIFF" --design "$BASE" --actual "$DIFF2" --out-dir "$OUTDIR" >/dev/null 2>&1
for f in diff-heatmap.png diff-annotated.png side-by-side.png; do
  if [ -s "$OUTDIR/$f" ]; then ok "产出 $f"; else bad "未产出 $f"; fi
done

# ------------------------------------------------------------
echo "== pixdiff:输入与参数校验 =="
assert_exit 1 "设计稿文件不存在 → exit 1" -- \
  python3 "$PIXDIFF" --design "$TMP/nope.png" --actual "$BASE"
assert_exit 1 "实现截图不存在 → exit 1" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$TMP/nope.png"
assert_exit 1 "--grid 0 → exit 1" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$SAME" --grid 0
assert_exit 1 "--tol 越界 → exit 1" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$SAME" --tol 300
assert_exit 1 "--threshold 负数 → exit 1" -- \
  python3 "$PIXDIFF" --design "$BASE" --actual "$SAME" --threshold -1
assert_exit 1 "非图片文件 → exit 1" -- \
  python3 "$PIXDIFF" --design "$DETECT" --actual "$BASE"

fi  # HAS_PILLOW

# ============================================================
# detect-stack.sh
# ============================================================
echo "== detect-stack:Flutter 项目(有 token 层)=="
FLUT="$TMP/proj-flutter"
mkdir -p "$FLUT/lib/theme" "$FLUT/scripts"
printf 'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$FLUT/pubspec.yaml"
printf 'class AppColors { static const bg = Color(0xFFFFFFFF); }\n' > "$FLUT/lib/theme/app_colors.dart"
printf '#!/bin/sh\necho run\n' > "$FLUT/scripts/run_app_iphone_test.sh"

assert_exit 0 "Flutter 项目探测完成(exit 0)" -- bash "$DETECT" "$FLUT"
assert_contains "技术栈      : flutter" "判定为 flutter" -- bash "$DETECT" "$FLUT"
assert_contains "lib/theme/app_colors.dart" "定位到 token 文件" -- bash "$DETECT" "$FLUT"
assert_contains "scripts/run_app_iphone_test.sh" "发现项目内 run 脚本" -- bash "$DETECT" "$FLUT"

echo "== detect-stack:Flutter 项目(无 token 层)=="
BARE="$TMP/proj-bare-flutter"
mkdir -p "$BARE/lib"
printf 'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$BARE/pubspec.yaml"
printf 'void main() {}\n' > "$BARE/lib/main.dart"
assert_contains "未找到 token/theme 层" "无 token 层时明确告警" -- bash "$DETECT" "$BARE"
assert_contains "主动建立" "无 token 层时给出建层指引" -- bash "$DETECT" "$BARE"

echo "== detect-stack:React + Tailwind 项目 =="
REACT="$TMP/proj-react"
mkdir -p "$REACT/src"
printf '{"dependencies":{"react":"19.0.0"},"scripts":{"dev":"vite"}}\n' > "$REACT/package.json"
printf 'module.exports = { theme: { extend: {} } }\n' > "$REACT/tailwind.config.js"
assert_contains "技术栈      : react" "判定为 react" -- bash "$DETECT" "$REACT"
assert_contains "tailwind.config.js" "发现 tailwind 配置" -- bash "$DETECT" "$REACT"
assert_contains "dev/start script" "发现 dev script" -- bash "$DETECT" "$REACT"

echo "== detect-stack:Next.js 优先于 react 判定 =="
NEXT="$TMP/proj-next"
mkdir -p "$NEXT"
printf '{"dependencies":{"next":"15.0.0","react":"19.0.0"}}\n' > "$NEXT/package.json"
assert_contains "技术栈      : next" "同时含 next 与 react 时判为 next" -- bash "$DETECT" "$NEXT"

echo "== detect-stack:CSS 变量作为 token 层 =="
CSSP="$TMP/proj-css"
mkdir -p "$CSSP/styles"
printf '{"dependencies":{"vue":"3.0.0"}}\n' > "$CSSP/package.json"
printf ':root {\n  --color-bg: #fff;\n}\n' > "$CSSP/styles/tokens.css"
assert_contains "CSS 变量" "识别 CSS 自定义属性为 token 层" -- bash "$DETECT" "$CSSP"

echo "== detect-stack:未知栈与无效目录 =="
EMPTY="$TMP/proj-empty"
mkdir -p "$EMPTY"
assert_contains "技术栈      : unknown" "空目录判为 unknown" -- bash "$DETECT" "$EMPTY"
assert_exit 1 "目录不存在 → exit 1" -- bash "$DETECT" "$TMP/does-not-exist"

# ============================================================
# figma-cache.sh —— 用隔离的 XDG_CACHE_HOME,不碰真实缓存
# ============================================================
CACHE_HOME="$TMP/cachehome"
mkdir -p "$CACHE_HOME"
fc() { env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" "$@"; }

KEY="abc123DEF456ghi789jkl0"   # 合法 fileKey:纯字母数字

echo "== figma-cache:未命中 / 写入 / 命中 =="
assert_exit 1 "空缓存 get 未命中 → exit 1" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables

printf '{"color/bg":"#FFFFFF"}\n' > "$TMP/vars.json"
assert_exit 0 "put 写入成功" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" put "$KEY" variables "$TMP/vars.json"
assert_exit 0 "写入后 get 命中 → exit 0" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables
assert_contains '"color/bg":"#FFFFFF"' "get 输出原始内容" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables
assert_contains "省下一次 MCP 调用" "命中时提示省了配额" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables

echo "== figma-cache:stdin 写入 =="
if printf '{"a":1}' | fc put "$KEY" codeconnect - >/dev/null 2>&1; then
  ok "支持从 stdin 写入"
else
  bad "从 stdin 写入失败"
fi
assert_contains '{"a":1}' "stdin 写入的内容可读回" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" codeconnect

echo "== figma-cache:两种 kind 互不覆盖 =="
assert_contains '"color/bg"' "variables 未被 codeconnect 覆盖" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables

echo "== figma-cache:空内容不留缓存 =="
: > "$TMP/empty.json"
assert_exit 2 "put 空文件 → exit 2" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" put "zzz999" variables "$TMP/empty.json"
assert_exit 1 "空内容未产生可命中的缓存" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "zzz999" variables

echo "== figma-cache:过期判定 =="
# 把 mtime 改到 40 天前
OLD="$CACHE_HOME/figma-to-page/$KEY.variables.json"
touch -t "$(python3 -c '
import datetime
print((datetime.date.today() - datetime.timedelta(days=40)).strftime("%Y%m%d") + "0000")
')" "$OLD" 2>/dev/null
assert_exit 1 "40 天前的缓存超过默认 30 天 → 视为过期" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables
assert_exit 0 "同一条缓存放宽到 60 天 → 命中" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables 60
assert_contains "已过期" "过期时给出提示" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" variables

echo "== figma-cache:参数校验(防路径穿越 / 拼错 kind)=="
assert_exit 2 "非法 kind → exit 2" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" tokens
assert_exit 2 "fileKey 含斜杠(路径穿越)→ exit 2" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "../../etc/passwd" variables
assert_exit 2 "fileKey 为空 → exit 2" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "" variables
assert_exit 2 "未知命令 → exit 2" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" bogus
assert_exit 2 "参数个数不对 → exit 2" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" put "$KEY" variables

echo "== figma-cache:list / clear =="
assert_contains "$KEY.variables.json" "list 列出缓存条目" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" list
assert_contains "天前" "list 显示缓存年龄" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" list
fc clear "$KEY" >/dev/null 2>&1
assert_exit 1 "clear <fileKey> 后不再命中" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" get "$KEY" codeconnect
assert_contains "(空)" "全部清除后 list 为空" -- \
  env XDG_CACHE_HOME="$CACHE_HOME" bash "$FCACHE" list

echo "== figma-cache:缓存目录不存在时不报错 =="
assert_exit 0 "空 XDG_CACHE_HOME 下 list 正常退出" -- \
  env XDG_CACHE_HOME="$TMP/nonexistent-cache" bash "$FCACHE" list
assert_exit 0 "缓存目录不存在时 clear 正常退出" -- \
  env XDG_CACHE_HOME="$TMP/nonexistent-cache" bash "$FCACHE" clear

# ============================================================
# quota-mode:取数模式解析
# ============================================================
CONF_HOME="$TMP/config"
# 每次都要隔离 XDG_CONFIG_HOME 并清掉 FIGMA_QUOTA_MODE,否则跑测试的人自己的配置会污染结果
qm() { env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE" "$@"; }

echo "== quota-mode:默认与配置读取 =="
assert_contains "MODE=auto" "无配置时默认 auto" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"
assert_contains "$CONF_HOME/figma-to-page/quota.conf" "where 打印配置路径" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE" where
qm set unlimited >/dev/null 2>&1
assert_contains "MODE=full" "配置 unlimited → full" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"
assert_contains "REPORT_QUOTA=no" "unlimited 不汇报配额" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"
qm set thrifty >/dev/null 2>&1
assert_contains "MODE=thrifty" "配置 thrifty → thrifty" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"
assert_contains "REPORT_QUOTA=yes" "thrifty 要汇报配额" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"

echo "== quota-mode:环境变量优先于配置文件 =="
assert_contains "MODE=full" "env 覆盖配置文件" -- \
  env FIGMA_QUOTA_MODE=unlimited XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"
assert_contains "环境变量" "来源标注为环境变量" -- \
  env FIGMA_QUOTA_MODE=unlimited XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"

echo "== quota-mode:配置文件解析健壮性 =="
printf '# 只有注释\n\n  thrifty  # 带尾注释和空格\n' > "$CONF_HOME/figma-to-page/quota.conf"
assert_contains "MODE=thrifty" "跳过注释/空行,去掉尾注释与空格" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"
printf 'unlimited\necho PWNED\n' > "$CONF_HOME/figma-to-page/quota.conf"
assert_not_contains "PWNED" "配置文件不被 source(不执行其中内容)" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"

echo "== quota-mode:非法值与用法错误 =="
assert_exit 2 "配置非法值 → exit 2" -- \
  env FIGMA_QUOTA_MODE=bogus XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE"
assert_exit 2 "set 非法值 → exit 2" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE" set bogus
assert_exit 2 "resolve 缺参数 → exit 2" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE" resolve Dev
assert_exit 2 "未知命令 → exit 2" -- \
  env -u FIGMA_QUOTA_MODE XDG_CONFIG_HOME="$CONF_HOME" bash "$QMODE" nope

echo "== quota-mode:auto 按 seat/tier 判定 =="
assert_contains "MODE=thrifty" "View + starter → thrifty(20/月)" -- \
  bash "$QMODE" resolve View starter
assert_contains "MODE=thrifty" "View + enterprise → thrifty(6/月,比 starter 还紧)" -- \
  bash "$QMODE" resolve View enterprise
assert_contains "MODE=thrifty" "Collab seat → thrifty" -- \
  bash "$QMODE" resolve Collab organization
assert_contains "MODE=thrifty" "Dev + starter → thrifty(starter 的 Dev 仍是 20/月)" -- \
  bash "$QMODE" resolve Dev starter
assert_contains "MODE=full" "Dev + professional → full(200/天)" -- \
  bash "$QMODE" resolve Dev professional
assert_contains "MODE=full" "Full + enterprise → full(600/天)" -- \
  bash "$QMODE" resolve Full enterprise
assert_contains "MODE=full" "seat/tier 大小写不敏感" -- \
  bash "$QMODE" resolve DEV Enterprise
assert_contains "MODE=thrifty" "未知 seat → 保守走 thrifty" -- \
  bash "$QMODE" resolve Mystery enterprise

# ============================================================
echo ""
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
if [ "$fail" = 0 ]; then
  printf "${GREEN}✅ 全部通过:%d 项${NC}\n" "$pass"
  exit 0
else
  printf "${RED}❌ 失败 %d 项(通过 %d 项)${NC}\n" "$fail" "$pass"
  exit 1
fi
