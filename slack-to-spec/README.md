# slack-to-spec 📋

把某个 Slack 频道一段时间内的讨论,收敛成一份**可落地的需求 spec 文档**。

核心价值不是"总结",而是:**抓住决策(尤其被推翻/取代的方案)+ 拎出隐藏的开发需求 + 划清开工红线**——让开发能照着干,三个月后还能回溯"为啥这么定"。

## 🚀 安装

把本目录拷进 Claude Code 的 skills 目录:

```bash
# 全局(所有项目可用)
cp -r slack-to-spec ~/.claude/skills/

# 或 项目级(只在当前项目生效)
cp -r slack-to-spec .claude/skills/
```

**重启 Claude Code** 后,对话里用 `/slack-to-spec` 即可触发。

### 依赖

- 已接入 **Slack MCP**,可用这些工具:`slack_search_channels` / `slack_read_channel` / `slack_read_thread` / `slack_read_canvas`(skill 会按需 `ToolSearch` 加载)。
- `date` 命令(算时间范围,系统自带)。

### 验证

重启后在对话里输入 `/slack-to-spec`,出现在 skill 列表即安装成功;或 `ls ~/.claude/skills/slack-to-spec` 确认目录就位。

## 📖 用法

```
/slack-to-spec <频道> [时间范围]
```

- `<频道>`:频道 ID(如 `C0XXXXXXX`)或频道名(如 `#example-channel`)。
- `[时间范围]`(可选,缺省 `7d`):相对 `24h`/`3d`/`7d`/`2w`,或绝对区间 `2026-06-01..2026-06-05`,或单个起点 `2026-06-01`(到现在)。

示例:

```
/slack-to-spec C0XXXXXXX 3d
/slack-to-spec #example-channel 2026-06-01..2026-06-05
```

产出:一份结构化、可追溯、能直接喂开发的 markdown spec(背景 / **决策日志** / 可验收需求点 / 影响面 / 开放问题 / 时间线 / 来源)。

> 完整流程、Spec 模板与硬规则见 [SKILL.md](./SKILL.md)。本 skill **只读 Slack、只产出本地文档**,不发消息、不碰线上系统。
