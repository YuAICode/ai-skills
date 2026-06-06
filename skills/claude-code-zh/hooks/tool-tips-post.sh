#!/usr/bin/env bash
# tool-tips-post.sh — claude-code-zh 命令中文提示
# PostToolUse hook:读取工具调用 JSON,输出一句中文说明,仅打印不做任何副作用。
# License: MIT

raw="$(cat)"

# 从 JSON 里取字段(用 python3 解析,稳;无 python3 则降级到 grep)
field() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$raw" | python3 -c '
import json,sys
key=sys.argv[1]
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
ti=d.get("tool_input",d) if isinstance(d,dict) else {}
v=d.get(key) or (ti.get(key) if isinstance(ti,dict) else None)
print(v if isinstance(v,str) else "")
' "$1"
  else
    printf '%s' "$raw" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//'
  fi
}

tool="$(field tool_name)"
[ -z "$tool" ] && exit 0
fpath="$(field file_path)"
cmd="$(field command)"
pat="$(field pattern)"
base="${fpath##*/}"

# 单条 shell 命令 → 中文说明
desc_shell() {
  set -- $1
  local head="$1" sub="$2"
  case "$head" in
    git)
      case "$sub" in
        status) echo "查看仓库改动状态";; log) echo "查看提交历史";;
        diff) echo "查看具体改动内容";; add) echo "把改动加入暂存区";;
        commit) echo "提交一次代码变更";; push) echo "上传到远程仓库";;
        pull) echo "拉取远程最新代码";; fetch) echo "获取远程更新信息";;
        checkout|switch) echo "切换分支";; branch) echo "管理分支";;
        merge) echo "合并分支";; rebase) echo "变基整理历史";;
        stash) echo "暂存未提交的改动";; clone) echo "克隆远程仓库";;
        reset) echo "回退提交或恢复文件";; revert) echo "新建提交以撤销改动";;
        tag) echo "管理版本标签";; remote) echo "管理远程地址";;
        *) echo "Git 操作";;
      esac;;
    npm|pnpm|yarn|bun)
      case "$sub" in
        i|install|add) echo "安装依赖";; run) echo "运行脚本";;
        build) echo "构建项目";; test) echo "跑测试";;
        start|dev) echo "启动项目";; *) echo "包管理操作";;
      esac;;
    npx|bunx) echo "临时运行一个包";;
    pip|pip3)
      case "$sub" in
        install) echo "安装 Python 依赖";; uninstall) echo "卸载 Python 包";;
        list|freeze) echo "查看依赖列表";; *) echo "Python 包管理";;
      esac;;
    python|python3) echo "运行 Python 脚本";;
    pytest) echo "跑 Python 测试";;
    go)
      case "$sub" in build) echo "编译 Go";; run) echo "运行 Go";; test) echo "跑 Go 测试";; mod) echo "管理 Go 模块";; *) echo "Go 操作";; esac;;
    cargo)
      case "$sub" in build) echo "编译 Rust";; run) echo "运行 Rust";; test) echo "跑 Rust 测试";; *) echo "Cargo 操作";; esac;;
    docker)
      case "$sub" in build) echo "构建镜像";; run) echo "运行容器";; ps) echo "查看容器";; compose|up) echo "启动多容器应用";; *) echo "Docker 操作";; esac;;
    make) echo "编译构建";;
    ls|dir) echo "列出目录文件";; cat|bat) echo "查看文件内容";;
    head) echo "看文件开头";; tail) echo "看文件结尾";;
    cd) echo "切换目录";; pwd) echo "显示当前路径";;
    rm) echo "删除文件";; cp) echo "复制文件";; mv) echo "移动/重命名";;
    mkdir) echo "新建目录";; touch) echo "新建空文件";;
    chmod) echo "改文件权限";; find) echo "查找文件";;
    grep|rg|ag) echo "搜索文本";; sed) echo "流式编辑文本";; awk) echo "处理文本字段";;
    curl|wget) echo "请求网络资源";; ssh) echo "远程登录";; scp) echo "远程传文件";;
    echo|printf) echo "输出文本";; export) echo "设置环境变量";;
    kill) echo "结束进程";; ps) echo "查看进程";;
    code) echo "用编辑器打开";; vim|vi|nano) echo "终端里编辑文件";;
    tar|zip|unzip) echo "压缩/解压";;
    *) echo "执行命令";;
  esac
}

# 组装提示文案
tip=""
case "$tool" in
  Read)        tip="📖 读取 ${base:-文件}";;
  Write)       tip="📝 写入 ${base:-文件}";;
  Edit|MultiEdit) tip="✏️ 编辑 ${base:-文件}";;
  Glob)        tip="🔍 按名称查找文件${pat:+:$pat}";;
  Grep)        tip="🔎 搜索内容${pat:+:$pat}";;
  Bash)
    first="$(printf '%s' "$cmd" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' | head -1)"
    if [ -n "$first" ]; then
      one="${first%%&&*}"; one="${one%%||*}"; one="${one%%;*}"
      one="$(printf '%s' "$one" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      tip="🖥️ $one — $(desc_shell "$one")"
    else
      tip="🖥️ 执行命令"
    fi;;
  Task|TodoWrite) tip="📋 任务/待办管理";;
  Agent)       tip="🤖 派出子助手处理任务";;
  Skill)       tip="⚡ 调用了一个技能";;
  EnterPlanMode) tip="🤔 进入规划模式";;
  ExitPlanMode)  tip="✅ 规划完成,准备执行";;
  mcp__*)
    rest="${tool#mcp__}"; srv="${rest%%__*}"; t="${rest#*__}"
    tip="🔌 ${srv}: ${t} — 调用扩展工具";;
  *)           tip="✅ ${tool} 完成";;
esac

[ -z "$tip" ] && exit 0

# 输出 systemMessage(JSON 转义)
msg="🌸 ${tip} 🌸"
if command -v python3 >/dev/null 2>&1; then
  printf '%s' "$msg" | python3 -c 'import json,sys;print(json.dumps({"systemMessage":sys.stdin.read()},ensure_ascii=False))'
else
  esc="${msg//\\/\\\\}"; esc="${esc//\"/\\\"}"
  printf '{"systemMessage":"%s"}\n' "$esc"
fi
exit 0
