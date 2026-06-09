# claude-code-zh:新增 ③ 中文 statusline —— 设计文档

- 日期:2026-06-09
- 范围:给 `skills/claude-code-zh` 增加第三项功能 —— 自前轻量中文状态栏(statusline)
- 仓库:YuAICode/ai-skills,目标目录 `skills/claude-code-zh/`

## 1. 背景与定位

`claude-code-zh` 现有两项功能,均为 bash+python3、可逆、零 npm 依赖:

1. ① CLAUDE.md 中文回复指令
2. ② tooltip hook(PostToolUse 弹中文命令解释)+ `tooltip` 开关命令

对比 `huangguang1999/ccstatusline-zh`(fork 重型 TS 项目、重译 72 个 UI 串、npm 重发、需持续追上游),本设计走相反路线:**用一只极小 bash 脚本自前实现中文状态栏**,继承本 skill 既有哲学——零 npm、可逆、不追上游。

Claude Code 通过 `settings.json` 的 `statusLine` 字段支持自定义状态栏:配置一个命令,Claude Code 把会话 JSON 喂到该命令的 stdin,命令打印一行文本即被渲染。因此**无需 fork ccstatusline** 即可得到中文状态栏。

落地后,README/SKILL 的 ③ 行从「❌ 界面 chrome 汉化技术上不可行」升级为:**statusline 层 ✅(自前轻量版);菜单/`/config` 等 chrome 仍 ❌(编译二进制不可改)**。

## 2. 设计原则(沿用现有 skill)

- 全部改动**可逆**:settings.json 改动前备份,退避被覆盖的原值,卸载时还原。
- settings.json 一律用 **python3** 安全读写(不用脆弱的 sed)。
- statusline 脚本**绝不报错**:每个取值带 fallback,缺字段/无 git 时优雅降级,结尾 `exit 0`。
- 状态栏**默认不装**(opt-in),因为 `settings.json.statusLine` 是单一槽位,自动写入会静默覆盖用户已有的状态栏(如本家 ccstatusline)。
- 兼容 bash 3.2(macOS);测试全程用临时 `CLAUDE_DIR`,绝不碰真实配置。

## 3. 显示内容

状态栏单行,三段(按此顺序),段间用 ` │ ` 分隔,整行用 `🌸` 包裹风格与 tooltip 统一:

| 段 | 来源 | 说明 |
| --- | --- | --- |
| 模型名 | stdin JSON `model.display_name` | 形如 `🤖 Opus 4.8`;取不到时回退到 `model.id`,再取不到则省略该段 |
| 当前目录 | stdin JSON `workspace.current_dir`(回退 `cwd`) | 显示 `basename`,形如 `📁 ai-skills` |
| Git 分支 | 脚本对目录调 `git` | 形如 ` main`,工作区脏则加 `*`;非 git 仓库/无 git 命令时整段省略 |

示例输出:

```
🌸 🤖 Opus 4.8 │ 📁 ai-skills │  main*
```

**不包含** token/上下文用量:该字段在不同 Claude Code 版本里不稳定,为保证跨版本可靠而排除。

## 4. 组件

### 4.1 `bin/statusline.sh`(新)—— statusLine 命令本体

- 从 stdin 读 JSON,用 python3 提取 `model.display_name` / `model.id` / `workspace.current_dir` / `cwd`。
- 目录段:对取到的目录取 basename。
- 分支段:`git -C "<dir>" rev-parse --abbrev-ref HEAD`(2>/dev/null);成功后用 `git -C "<dir>" status --porcelain` 是否非空判断脏标 `*`。`git` 不存在或非仓库时整段跳过。
- 组装三段,存在的才拼接,段间 ` │ `,前缀/后缀 `🌸`。
- 性能:只调最小限度 git 命令;无网络、无写文件。
- 健壮性:任一步失败都不致命,最终 `exit 0`,至少输出能取到的部分(全空则输出空行)。
- 依赖:`bash` + `python3`(与现有 hook 一致);`git` 为可选增强。

### 4.2 `bin/ccstatus.sh`(新)—— 开关命令(仿 `bin/tooltip.sh`)

接受 `on` / `off` / `status` / 无参(切换),通过 python3 编辑 `settings.json`:

- `on`:
  - 若当前 `data.statusLine` 存在且**不是**我们的(command 不指向我们的脚本),先把它原样退避到 `$CLAUDE_DIR/ccstatus.prev.json`。
  - 写入 `data.statusLine = {"type":"command","command":"~/.claude/bin/statusline.sh","padding":0}`。
- `off`:
  - 若 `ccstatus.prev.json` 存在,用它还原 `data.statusLine`,然后删除该退避文件。
  - 否则删除 `data.statusLine` 键。
- `status`:报告当前 statusLine 是否为我们的(开启/关闭),并提示重启 Claude Code 生效。
- 任何写入前若无备份则照现有约定备份 `settings.json.zh.bak`;写入后保证仍是合法 JSON。

### 4.3 `install.sh` 追加

- 复制 `bin/statusline.sh` → `~/.claude/bin/statusline.sh`(chmod 755)。
- 复制 `bin/ccstatus.sh` → `~/.claude/bin/ccstatus`(chmod 755)。
- 在 `~/.zshrc` / `~/.bashrc` 用 sentinel 幂等加 `alias ccstatus='bash ~/.claude/bin/ccstatus'`(与 `tooltip` 别名同一模式,单独 sentinel 行便于卸载)。
- **不写 settings.json 的 statusLine**(opt-in)。安装末尾提示:`ccstatus on` 开启中文状态栏。

### 4.4 `uninstall.sh` 追加

- 若 `data.statusLine` 指向我们的脚本:执行等价于 `ccstatus off` 的还原(有 prev 还原、无则删键)。
- 删除 `~/.claude/bin/statusline.sh`、`~/.claude/bin/ccstatus`、`~/.claude/ccstatus.prev.json`。
- 移除 rc 文件里的 `ccstatus` alias sentinel 区块。

### 4.5 `tests/run.sh` 追加(临时 CLAUDE_DIR)

- statusline 输出:
  - 喂样例 JSON(含 model.display_name + workspace.current_dir),断言输出含模型名、目录 basename、`🌸`。
  - model 段缺失时不崩、仍输出目录段。
  - 在临时 git 仓库里对该目录运行,断言出现分支名;非 git 目录时不含分支段且不报错。
- ccstatus 开关:
  - 预置一个「别人的」statusLine,`ccstatus on` 后断言 prev.json 已退避且 settings.json 合法、statusLine 指向我们的。
  - `ccstatus off` 后断言原 statusLine 被还原、prev.json 已删、JSON 合法。
  - 无原 statusLine 时 `on`→`off` 后断言 statusLine 键被干净删除。

### 4.6 文档更新

- `SKILL.md`:能力表 ③ 行改为 statusline ✅;新增 `ccstatus on|off|status` 用法与示例。
- `README.md`:同步 ③ 行、加状态栏效果示例、加「🔘 一键开关 statusline」小节(仿 tooltip 小节)。

## 5. 不改动的部分

① CLAUDE.md 中文回复、② tooltip hook 完全不动。`statusLine` 与 `PostToolUse` 是 settings.json 的不同键,互不干扰。

## 6. 验收标准

- `bash tests/run.sh` 全绿(含新增 statusline / ccstatus 用例)。
- `skill-doctor` 对本 skill 通过(frontmatter / name 匹配 / README 徽章 / 有 bin 必有 tests)。
- 真机:`ccstatus on` 后重启 Claude Code,底部出现中文三段状态栏;`ccstatus off` 后还原为原状态栏(或消失);`uninstall.sh` 后无残留。
- 全程零 npm 依赖,所有 settings.json 改动可逆。
