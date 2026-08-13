#!/usr/bin/env python3
"""pixdiff.py — 设计稿与实现截图的像素级偏差对比 + 分块偏差排行。

用途:figma-to-page skill 的校验闭环。把「看着差不多」换成可量化、可收敛的数字,
并给出按偏差排序的区块清单,让模型只针对偏差最大的区域改,而不是盯整张图找差异。

用法:
    pixdiff.py --design <设计稿.png> --actual <实现截图.png> [选项]

选项:
    --grid N          横向切 N 列(纵向按比例切,尽量保持方块),默认 12
    --threshold PCT   通过阈值:偏差像素占比 <= PCT 即算通过,默认 1.0
    --tol N           单像素容差:通道最大差值 > N 才算「偏差像素」,默认 12
    --top N           输出偏差最大的 N 个区块,默认 8
    --out-dir DIR     输出差异图/热力图目录;不传则不产图
    --json            以 JSON 输出(供程序解析),否则输出人类可读报告

退出码:
    0  通过(偏差 <= threshold)
    2  未通过(偏差 > threshold)
    1  用法或输入错误
    3  缺少 Pillow —— 调用方应降级为模型肉眼对比,不要当作失败
"""

import argparse
import json
import os
import sys

# ------------------------------------------------------------------
# Pillow 优雅降级:缺失时以退出码 3 明确告知调用方降级,而不是抛栈崩掉
# ------------------------------------------------------------------
try:
    from PIL import Image, ImageChops, ImageStat, ImageDraw
except ImportError:
    sys.stderr.write(
        "[pixdiff] 未安装 Pillow,无法做像素级对比。\n"
        "  安装:python3 -m pip install Pillow\n"
        "  降级方案:把设计稿与实现截图并排交给模型做肉眼对比(无量化阈值,"
        "需人工判断是否收敛)。\n"
    )
    sys.exit(3)


def load_rgb(path):
    """读图并统一成 RGB。带 alpha 的图合成到白底,避免透明区域被当成黑色误判。"""
    if not os.path.isfile(path):
        sys.stderr.write("[pixdiff] 文件不存在: %s\n" % path)
        sys.exit(1)
    try:
        img = Image.open(path)
        img.load()
    except Exception as exc:  # noqa: BLE001 - 任何解码失败都归为输入错误
        sys.stderr.write("[pixdiff] 无法读取图片 %s: %s\n" % (path, exc))
        sys.exit(1)

    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
        img = Image.alpha_composite(bg, img)
    return img.convert("RGB")


def max_channel_diff(a, b):
    """逐像素取 RGB 三通道差值的最大值,返回单通道(L)差异图。

    用 ImageChops 走 C 层实现;不用 Python 循环,也不依赖 numpy。
    取「最大通道差」而非亮度差,是为了不漏掉纯色相偏移(亮度相近但颜色明显不同)。
    """
    diff = ImageChops.difference(a, b)
    r, g, bl = diff.split()
    return ImageChops.lighter(ImageChops.lighter(r, g), bl)


def changed_ratio(mask_l, tol):
    """偏差像素占比:通道最大差值 > tol 的像素比例。

    先用 point() 做 LUT 二值化(C 层),再用 ImageStat 求均值,避免逐像素遍历。
    """
    binary = mask_l.point(lambda v: 255 if v > tol else 0)
    return ImageStat.Stat(binary).mean[0] / 255.0, binary


def block_bounds(width, height, cols):
    """按列数切网格,行数按图像长宽比推算,使每块尽量接近正方形。"""
    cols = max(1, min(cols, width))
    block_w = width / float(cols)
    rows = max(1, int(round(height / block_w)))
    block_h = height / float(rows)

    bounds = []
    for row in range(rows):
        for col in range(cols):
            left = int(round(col * block_w))
            upper = int(round(row * block_h))
            right = int(round((col + 1) * block_w)) if col < cols - 1 else width
            lower = int(round((row + 1) * block_h)) if row < rows - 1 else height
            if right > left and lower > upper:
                bounds.append((row, col, left, upper, right, lower))
    return bounds, rows, cols


def analyse(design, actual, cols, tol):
    """核心分析:对齐尺寸 → 全局偏差 → 分块偏差排行。"""
    warnings = []

    dw, dh = design.size
    aw, ah = actual.size

    # 设计稿尺寸为基准。实现截图通常因 DPR / 缩放而尺寸不同,统一缩放到设计稿尺寸。
    if (aw, ah) != (dw, dh):
        design_ratio = dw / float(dh)
        actual_ratio = aw / float(ah)
        # 长宽比差异过大通常意味着截错了区域(滚动位置不同、含状态栏、裁剪范围不对),
        # 这种情况下缩放对比出来的数字没有意义,必须提醒而不是硬算。
        if abs(design_ratio - actual_ratio) / design_ratio > 0.05:
            warnings.append(
                "长宽比不一致(设计稿 %.3f vs 实现 %.3f,差异 >5%%)。"
                "很可能截图区域不对(滚动位置、状态栏、裁剪范围),"
                "请先修正截图范围再看偏差数字。"
                % (design_ratio, actual_ratio)
            )
        actual = actual.resize((dw, dh), Image.LANCZOS)
        warnings.append(
            "实现截图已从 %dx%d 缩放到设计稿尺寸 %dx%d 后对比。" % (aw, ah, dw, dh)
        )

    diff_l = max_channel_diff(design, actual)
    overall_ratio, binary = changed_ratio(diff_l, tol)
    mean_diff = ImageStat.Stat(diff_l).mean[0] / 255.0

    bounds, rows, cols_used = block_bounds(dw, dh, cols)
    blocks = []
    for row, col, left, upper, right, lower in bounds:
        box = (left, upper, right, lower)
        block_bin = binary.crop(box)
        block_diff = diff_l.crop(box)
        area = (right - left) * (lower - upper)
        ratio = ImageStat.Stat(block_bin).mean[0] / 255.0
        blocks.append(
            {
                "row": row,
                "col": col,
                "box": [left, upper, right, lower],
                "area": area,
                "changed_px": int(round(ratio * area)),
                "changed_pct": round(ratio * 100.0, 3),
                "mean_diff_pct": round(
                    ImageStat.Stat(block_diff).mean[0] / 255.0 * 100.0, 3
                ),
            }
        )

    blocks.sort(key=lambda b: (-b["changed_pct"], -b["mean_diff_pct"]))

    return {
        "size": [dw, dh],
        "grid": {"rows": rows, "cols": cols_used},
        "overall_changed_pct": round(overall_ratio * 100.0, 3),
        "overall_mean_diff_pct": round(mean_diff * 100.0, 3),
        "blocks": blocks,
        "warnings": warnings,
    }, diff_l, binary, actual


def cluster_blocks(blocks, floor_pct):
    """把相邻的偏差区块聚合成「缺陷簇」,按偏差像素总量排序。

    为什么需要这一层:一个真实缺陷(如按钮整体下移 8px)会横跨多个相邻网格,
    若直接按区块排行,top-N 会被同一个缺陷占满,模型误以为有 N 个独立问题要修。
    聚合后 top-N 才是 N 个**不同**的缺陷,这才是有用的待修清单。

    用 4 邻域连通(上下左右),迭代式 BFS(不递归,避免大图爆栈)。
    """
    offending = {
        (b["row"], b["col"]): b for b in blocks if b["changed_pct"] > floor_pct
    }
    seen = set()
    clusters = []

    for key in offending:
        if key in seen:
            continue
        # BFS 收集一个连通簇
        queue = [key]
        seen.add(key)
        members = []
        while queue:
            cur = queue.pop()
            members.append(offending[cur])
            row, col = cur
            for nb in ((row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)):
                if nb in offending and nb not in seen:
                    seen.add(nb)
                    queue.append(nb)

        left = min(m["box"][0] for m in members)
        upper = min(m["box"][1] for m in members)
        right = max(m["box"][2] for m in members)
        lower = max(m["box"][3] for m in members)
        changed_px = sum(m["changed_px"] for m in members)
        area = sum(m["area"] for m in members)
        # 平均色差按各块面积加权,避免小块拉高整簇数字
        weighted = sum(m["mean_diff_pct"] * m["area"] for m in members)

        clusters.append(
            {
                "box": [left, upper, right, lower],
                "block_count": len(members),
                "changed_px": changed_px,
                "changed_pct": round(changed_px / float(area) * 100.0, 3) if area else 0.0,
                "mean_diff_pct": round(weighted / float(area), 3) if area else 0.0,
            }
        )

    clusters.sort(key=lambda c: -c["changed_px"])
    return clusters


def write_outputs(out_dir, design, actual, diff_l, result, top):
    """产出热力图与标注图,便于模型定位偏差区域。"""
    os.makedirs(out_dir, exist_ok=True)
    paths = {}

    # 热力图:差异放大 4 倍便于肉眼看清微小偏移(饱和到 255)
    heat = diff_l.point(lambda v: min(255, v * 4))
    heat_path = os.path.join(out_dir, "diff-heatmap.png")
    heat.save(heat_path)
    paths["heatmap"] = heat_path

    # 标注图:在实现截图上框出 top-N 缺陷簇,并标序号(与报告表格的 # 对应)
    annotated = actual.copy()
    draw = ImageDraw.Draw(annotated)
    for idx, cluster in enumerate(result["clusters"][:top], start=1):
        left, upper, right, lower = cluster["box"]
        draw.rectangle([left, upper, right - 1, lower - 1], outline=(255, 0, 0), width=3)
        draw.text((left + 5, upper + 5), "#%d" % idx, fill=(255, 0, 0))
    annotated_path = os.path.join(out_dir, "diff-annotated.png")
    annotated.save(annotated_path)
    paths["annotated"] = annotated_path

    # 并排图:左设计稿、右实现,供模型直接肉眼对照
    dw, dh = design.size
    side = Image.new("RGB", (dw * 2 + 16, dh), (255, 255, 255))
    side.paste(design, (0, 0))
    side.paste(actual, (dw + 16, 0))
    side_path = os.path.join(out_dir, "side-by-side.png")
    side.save(side_path)
    paths["side_by_side"] = side_path

    return paths


def print_report(result, threshold, tol, top, paths, passed):
    print("[pixdiff] 设计稿还原度对比")
    print("━" * 48)
    for warning in result["warnings"]:
        print("⚠  %s" % warning)
    if result["warnings"]:
        print("")

    print("尺寸基准    : %dx%d" % tuple(result["size"]))
    print("网格        : %d 行 × %d 列" % (result["grid"]["rows"], result["grid"]["cols"]))
    print("单像素容差  : 通道最大差值 > %d 记为偏差" % tol)
    print("")
    print("偏差像素占比: %.3f%%   (阈值 %.3f%%)" % (result["overall_changed_pct"], threshold))
    print("平均色差    : %.3f%%" % result["overall_mean_diff_pct"])
    print("")

    clusters = result["clusters"][:top]
    if clusters:
        print("待修缺陷(相邻偏差区块已聚合;序号对应 diff-annotated.png 的红框):")
        print(
            "  %-4s %-24s %-11s %-11s %s"
            % ("#", "区域 (l,t,r,b)", "偏差像素数", "区内偏差%", "平均色差%")
        )
        for idx, cluster in enumerate(clusters, start=1):
            left, upper, right, lower = cluster["box"]
            print(
                "  %-4d %-24s %-11d %-11.3f %.3f"
                % (
                    idx,
                    "%d,%d,%d,%d" % (left, upper, right, lower),
                    cluster["changed_px"],
                    cluster["changed_pct"],
                    cluster["mean_diff_pct"],
                )
            )
        total = len(result["clusters"])
        if total > len(clusters):
            print("  …另有 %d 个较小缺陷簇未列出(--top 可调)。" % (total - len(clusters)))
    else:
        print("无可见缺陷簇。")
    print("")

    if paths:
        print("产出图片:")
        for key in ("heatmap", "annotated", "side_by_side"):
            if key in paths:
                print("  %-14s %s" % (key, paths[key]))
        print("")

    if passed:
        print("✅ 通过:偏差 %.3f%% <= 阈值 %.3f%%" % (result["overall_changed_pct"], threshold))
    else:
        print("❌ 未通过:偏差 %.3f%% > 阈值 %.3f%%" % (result["overall_changed_pct"], threshold))
        print("   下一步:按上表从 #1 开始修,改完重新截图再跑本脚本。")
        print("   若连续两轮偏差无改善,停止迭代并如实报告残留偏差,不要假装收敛。")


def main():
    parser = argparse.ArgumentParser(
        description="设计稿与实现截图的像素偏差对比 + 分块排行",
        add_help=True,
    )
    parser.add_argument("--design", required=True, help="设计稿截图路径(基准)")
    parser.add_argument("--actual", required=True, help="实现页面截图路径")
    parser.add_argument("--grid", type=int, default=12, help="横向切分列数,默认 12")
    parser.add_argument(
        "--threshold", type=float, default=1.0, help="通过阈值(偏差像素百分比),默认 1.0"
    )
    parser.add_argument("--tol", type=int, default=12, help="单像素通道容差,默认 12")
    parser.add_argument("--top", type=int, default=8, help="输出偏差最大的 N 个缺陷簇,默认 8")
    parser.add_argument(
        "--cluster-floor",
        type=float,
        default=2.0,
        help="区块偏差超过该百分比才参与缺陷簇聚合,用于滤掉抗锯齿噪声,默认 2.0",
    )
    parser.add_argument("--out-dir", default=None, help="差异图输出目录;不传则不产图")
    parser.add_argument("--json", action="store_true", help="以 JSON 输出")
    args = parser.parse_args()

    if args.grid < 1:
        sys.stderr.write("[pixdiff] --grid 必须 >= 1\n")
        sys.exit(1)
    if args.tol < 0 or args.tol > 255:
        sys.stderr.write("[pixdiff] --tol 必须在 0..255 之间\n")
        sys.exit(1)
    if args.threshold < 0:
        sys.stderr.write("[pixdiff] --threshold 必须 >= 0\n")
        sys.exit(1)

    design = load_rgb(args.design)
    actual = load_rgb(args.actual)

    result, diff_l, _binary, scaled_actual = analyse(design, actual, args.grid, args.tol)
    result["clusters"] = cluster_blocks(result["blocks"], args.cluster_floor)
    passed = result["overall_changed_pct"] <= args.threshold

    paths = {}
    if args.out_dir:
        paths = write_outputs(args.out_dir, design, scaled_actual, diff_l, result, args.top)

    if args.json:
        payload = dict(result)
        payload["clusters"] = result["clusters"][: args.top]
        payload["cluster_total"] = len(result["clusters"])
        payload["blocks"] = result["blocks"][: args.top]
        payload["threshold_pct"] = args.threshold
        payload["tol"] = args.tol
        payload["passed"] = passed
        payload["outputs"] = paths
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print_report(result, args.threshold, args.tol, args.top, paths, passed)

    sys.exit(0 if passed else 2)


if __name__ == "__main__":
    main()
