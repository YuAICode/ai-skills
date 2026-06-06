#!/usr/bin/env bash
# dockerfile-doctor/bin/check.sh — 扫描 Dockerfile 常见反模式
# 用法:
#   check.sh [Dockerfile路径]   默认 ./Dockerfile
# 退出码:0=干净 / 2=发现问题
set -uo pipefail

DOCKERFILE="${1:-./Dockerfile}"

# 规范化为绝对路径(兼容 bash 3.2,不用 realpath)
case "$DOCKERFILE" in
  /*) ;;
  *) DOCKERFILE="$(pwd)/$DOCKERFILE" ;;
esac

DOCKERFILE_DIR="$(dirname "$DOCKERFILE")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

if [ ! -f "$DOCKERFILE" ]; then
  printf "${RED}[错误]${NC} 文件不存在:%s\n" "$DOCKERFILE" >&2
  exit 1
fi

issues=0
has_user_nonroot=0
run_count=0

# ---- 工具:报告问题 ----
report() {
  local lineno="$1" msg="$2"
  printf "${RED}[问题]${NC} 第 %s 行:%s\n" "$lineno" "$msg"
  issues=$((issues+1))
}

warn() {
  local msg="$1"
  printf "${YELLOW}[提示]${NC} %s\n" "$msg"
  issues=$((issues+1))
}

# ---- 逐行扫描 ----
lineno=0
apt_install_seen=0
apt_cleanup_seen=0
copy_dot_seen=0
dep_install_seen=0

while IFS= read -r line; do
  lineno=$((lineno+1))

  # 跳过注释行和空行
  trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
  case "$trimmed" in
    '#'*|'') continue ;;
  esac

  # 1. FROM :latest 或无 tag
  case "$trimmed" in
    FROM\ *|from\ *)
      image="$(printf '%s' "$trimmed" | sed 's/^[Ff][Rr][Oo][Mm][[:space:]]*//' | awk '{print $1}')"
      # 去掉 AS alias
      image="$(printf '%s' "$image" | sed 's/ .*$//')"
      case "$image" in
        scratch) ;;  # scratch 没有 tag,合法
        *:latest) report "$lineno" "基础镜像使用了 ':latest' tag(不可复现,建议指定确定版本,如 node:20.11-alpine)" ;;
        *:*) ;;      # 有明确 tag,OK
        *) report "$lineno" "基础镜像 '$image' 没有指定 tag(不可复现,应写成 image:版本)" ;;
      esac
      ;;
  esac

  # 2. USER 指令检测(只要有 USER 且不是 root/0 就算非 root)
  case "$trimmed" in
    USER\ *|user\ *)
      user_val="$(printf '%s' "$trimmed" | sed 's/^[Uu][Ss][Ee][Rr][[:space:]]*//')"
      case "$user_val" in
        root|0) ;;  # 明确切回 root,不算设置了非 root
        *) has_user_nonroot=1 ;;
      esac
      ;;
  esac

  # 3. apt-get install 检测
  case "$trimmed" in
    *apt-get\ install*|*apt\ install*)
      apt_install_seen=$((apt_install_seen+1))
      # 同行有没有 --no-install-recommends
      case "$trimmed" in
        *--no-install-recommends*) ;;
        *) report "$lineno" "apt-get install 未加 '--no-install-recommends'(会安装推荐依赖,增大镜像体积)" ;;
      esac
      ;;
  esac

  # 4. apt 缓存清理
  case "$trimmed" in
    *rm\ -rf\ /var/lib/apt/lists*) apt_cleanup_seen=1 ;;
  esac

  # 5. ADD 用于本地文件(不是 URL 也不是 .tar.gz 解压场景)
  case "$trimmed" in
    ADD\ *|add\ *)
      src="$(printf '%s' "$trimmed" | sed 's/^[Aa][Dd][Dd][[:space:]]*//' | awk '{print $1}')"
      case "$src" in
        http://*|https://*) ;;  # URL 用 ADD 可接受(虽然 curl 更好)
        *.tar.gz|*.tgz|*.tar.bz2|*.tar.xz|*.tar) ;;  # 需要解压时 ADD 合理
        *) report "$lineno" "ADD 用于本地文件 '$src',应优先使用 COPY(ADD 有隐式解压/URL拉取副作用,语义不明确)" ;;
      esac
      ;;
  esac

  # 6. COPY . . 放在依赖安装之前(破坏构建缓存)
  #    标记依赖安装指令
  case "$trimmed" in
    *npm\ install*|*npm\ ci*|*yarn\ install*|*pip\ install*|*go\ mod\ download*|*go\ get*|*bundle\ install*|*composer\ install*)
      dep_install_seen=1
      ;;
  esac

  case "$trimmed" in
    COPY\ .\ .*|COPY\ ./\ *|copy\ .\ *|copy\ ./\ *)
      if [ "$dep_install_seen" -eq 0 ]; then
        report "$lineno" "COPY . . 出现在依赖安装指令之前(源码任意改动都会让依赖安装层缓存失效,应先 COPY 依赖清单再安装,最后再 COPY . .)"
        copy_dot_seen=1
      fi
      ;;
  esac

  # 7. ENV/ARG 疑似密钥
  case "$trimmed" in
    ENV\ *|env\ *|ARG\ *|arg\ *)
      kv="$(printf '%s' "$trimmed" | sed 's/^[A-Za-z]*[[:space:]]*//')"
      # 检查 key 是否含敏感词,且等号后有非空非占位符值
      if printf '%s' "$kv" | grep -qiE '(password|token|secret|api[_-]?key|access[_-]?key|private[_-]?key)='; then
        val="$(printf '%s' "$kv" | sed 's/^[^=]*=//')"
        # 跳过空值或占位符
        is_placeholder=0
        case "$val" in
          ''|'""'|"''") is_placeholder=1 ;;
        esac
        if [ "$is_placeholder" -eq 0 ] && printf '%s' "$val" | grep -qE '(\$\{|\$\(|placeholder|changeme|your_|<[^>]*>)'; then
          is_placeholder=1
        fi
        if [ "$is_placeholder" -eq 0 ]; then
          report "$lineno" "疑似将密钥/凭据写入 ENV/ARG(密钥会固化在镜像层中,docker history 可见;建议用 BuildKit --secret 或运行时注入)"
        fi
      fi
      ;;
  esac

  # 8. 统计 RUN 指令数
  case "$trimmed" in
    RUN\ *|run\ *) run_count=$((run_count+1)) ;;
  esac

done < "$DOCKERFILE"

# ---- 文件级检查 ----

# apt install 有但没清理
if [ "$apt_install_seen" -gt 0 ] && [ "$apt_cleanup_seen" -eq 0 ]; then
  warn "apt-get install 后未清理 '/var/lib/apt/lists/*'(每层 apt 缓存都会留在镜像里,体积膨胀;建议在同一 RUN 指令末尾加 'rm -rf /var/lib/apt/lists/*')"
fi

# 没有非 root 用户
if [ "$has_user_nonroot" -eq 0 ]; then
  warn "Dockerfile 中未设置非 root 用户(容器默认以 root 运行,存在安全风险;建议末尾加 'USER nobody' 或创建专用用户)"
fi

# .dockerignore 检查
if [ ! -f "$DOCKERFILE_DIR/.dockerignore" ]; then
  warn "目录 '$DOCKERFILE_DIR' 中未找到 .dockerignore(可能把 .git、node_modules 等不必要的文件打入镜像;建议添加 .dockerignore)"
fi

# 多条 RUN 提示(弱)
if [ "$run_count" -ge 4 ]; then
  warn "发现 $run_count 条独立的 RUN 指令(每条 RUN 都会新增一个镜像层;相关命令可用 && 合并为一条 RUN 以减小层数)"
fi

# ---- 汇总 ----
echo ""
if [ "$issues" -eq 0 ]; then
  printf "${GREEN}[通过]${NC} 未发现已知问题,Dockerfile 符合常见最佳实践。\n"
  exit 0
else
  printf "${RED}[汇总]${NC} 共发现 %d 个问题/提示,请逐条处理。\n" "$issues"
  exit 2
fi
