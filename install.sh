#!/usr/bin/env bash
# ==============================================================================
# ascend-fae-skills 安装脚本
# 支持 Linux / macOS / Windows (Git Bash)
#
# 用法:
#   bash install.sh             安装
#   bash install.sh --uninstall  卸载
# ==============================================================================
set -e

# ---- 配置 ----
PLUGIN_NAME="ascend-fae-skills"
PLUGIN_VERSION="0.1.0"

# ---- 路径 ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
PLUGIN_LINK="${SKILLS_DIR}/${PLUGIN_NAME}"

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- 确认 ----
confirm() {
  local msg="$1"
  local ans
  echo ""
  printf "${YELLOW}⚠  %s [y/N]: ${NC}" "$msg"
  read -r ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- 检测是否为 Windows ----
is_windows() {
  case "$(uname -s)" in
    CYGWIN*|MINGW*|MSYS*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- 创建目录链接 ----
create_link() {
  local target="$1"   # 实际项目目录
  local link="$2"     # 链接位置

  if is_windows; then
    # Windows: 使用 PowerShell 创建 Junction（真正的目录链接，不是复制）
    local win_target
    local win_link
    win_target=$(powershell -Command "[System.IO.Path]::GetFullPath('$target')" 2>/dev/null || cygpath -w "$target")
    win_link=$(powershell -Command "[System.IO.Path]::GetFullPath('$link')" 2>/dev/null || cygpath -w "$link")
    powershell -Command "New-Item -Path '$win_link' -ItemType Junction -Target '$win_target' -Force" >/dev/null 2>&1
  else
    ln -sfn "$target" "$link"
  fi
}

# ---- 删除链接 ----
remove_link() {
  local link="$1"

  if [ -L "$link" ] || [ -d "$link" ]; then
    if is_windows; then
      # Windows Junction: 用 rmdir 删除（不是 del，否则会删目标内容）
      local win_link
      win_link=$(powershell -Command "[System.IO.Path]::GetFullPath('$link')" 2>/dev/null || cygpath -w "$link")
      powershell -Command "
        \$item = Get-Item '$win_link' -ErrorAction SilentlyContinue
        if (\$item -and \$item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
          Remove-Item '$win_link' -Force
        }
      " >/dev/null 2>&1
    else
      rm -f "$link"
    fi
  fi
}

# ---- 查找 Python ----
find_python() {
  for py in python python3; do
    if command -v "$py" >/dev/null 2>&1 && "$py" -c "print('ok')" >/dev/null 2>&1; then
      echo "$py"
      return
    fi
  done
  echo ""
}

# ---- 清理旧的 @local 注册（从旧版 install.sh 遗留）----
cleanup_legacy_registration() {
  local py
  py=$(find_python)
  if [ -z "$py" ]; then
    return
  fi

  local legacy_key="${PLUGIN_NAME}@local"
  local installed_json="${CLAUDE_DIR}/plugins/installed_plugins.json"
  local settings_json="${CLAUDE_DIR}/settings.json"

  "$py" -c "
import json, sys

legacy_key = sys.argv[1]
installed_json = sys.argv[2]
settings_json = sys.argv[3]

# 从 installed_plugins.json 清理
try:
    with open(installed_json, 'r') as f:
        data = json.load(f)
    if 'plugins' in data and legacy_key in data['plugins']:
        del data['plugins'][legacy_key]
        with open(installed_json, 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        print(f'  ✓ 已清理旧注册: {legacy_key}')
except (FileNotFoundError, json.JSONDecodeError):
    pass

# 从 settings.json 清理
try:
    with open(settings_json, 'r') as f:
        data = json.load(f)
    if 'enabledPlugins' in data and legacy_key in data['enabledPlugins']:
        del data['enabledPlugins'][legacy_key]
        with open(settings_json, 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        print(f'  ✓ 已清理旧启用记录: {legacy_key}')
except (FileNotFoundError, json.JSONDecodeError):
    pass
" "$legacy_key" "$installed_json" "$settings_json" 2>/dev/null || true
}

# ==============================================================================
# 卸载
# ==============================================================================
do_uninstall() {
  echo ""
  echo "=== 卸载 ${PLUGIN_NAME} ==="
  echo ""

  # 删除目录链接
  if [ -L "${PLUGIN_LINK}" ] || [ -d "${PLUGIN_LINK}" ]; then
    remove_link "${PLUGIN_LINK}"
    log_info "已移除 ${PLUGIN_LINK}"
  else
    log_info "[SKIP] ${PLUGIN_LINK} 不存在"
  fi

  # 清理旧版注册
  cleanup_legacy_registration

  echo ""
  log_info "卸载完成！"
  exit 0
}

# ---- 处理命令行参数 ----
if [ "${1:-}" = "--uninstall" ] || [ "${1:-}" = "-u" ]; then
  do_uninstall
fi

# ==============================================================================
# 安装主流程
# ==============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ascend-fae-skills 安装脚本                          ║"
echo "║  Claude Code 插件 — 昇腾 FAE 技能集                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  项目目录: ${PROJECT_DIR}"
echo "  链接位置: ${PLUGIN_LINK}"
echo ""

# ---- 检查插件文件 ----
if [ ! -f "${PROJECT_DIR}/.claude-plugin/plugin.json" ]; then
  log_error "未找到 .claude-plugin/plugin.json"
  log_error "请在 ascend-fae-skills 项目根目录运行此脚本"
  exit 1
fi

# ---- 检查技能目录 ----
SKILL_COUNT=0
if [ -d "${PROJECT_DIR}/skills" ]; then
  for skill_dir in "${PROJECT_DIR}"/skills/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
      SKILL_COUNT=$((SKILL_COUNT + 1))
    fi
  done
fi

if [ "${SKILL_COUNT}" -eq 0 ]; then
  log_warn "未在 skills/ 目录中找到任何技能（SKILL.md）"
  log_warn "插件安装后可能没有可用技能"
  confirm "继续安装？" || exit 0
else
  log_info "找到 ${SKILL_COUNT} 个技能"
fi

# ---- 确保 skills 目录存在 ----
mkdir -p "${SKILLS_DIR}"

# ---- 检查是否已安装 ----
if [ -L "${PLUGIN_LINK}" ] || [ -d "${PLUGIN_LINK}" ]; then
  log_warn "${PLUGIN_LINK} 已存在，将覆盖"
  remove_link "${PLUGIN_LINK}"
fi

# ---- 创建目录链接 ----
log_info "创建目录链接..."
create_link "${PROJECT_DIR}" "${PLUGIN_LINK}"
log_info "已链接: ${PLUGIN_LINK} → ${PROJECT_DIR}"

# ---- 清理旧版 @local 注册（如果存在）----
cleanup_legacy_registration

# ---- 完成 ----
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ 安装完成！                                     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

if [ "${SKILL_COUNT}" -gt 0 ]; then
  echo "  已安装技能:"
  for skill_dir in "${PROJECT_DIR}"/skills/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
      skill_name=$(basename "${skill_dir}")
      echo "    - ${skill_name}"
    fi
  done
fi

echo ""
echo "  插件加载为: ${PLUGIN_NAME}@skills-dir"
echo "  使用方式: /ascend-fae-skills:download_weight"
echo ""
echo "  重启 Claude Code 后生效"
echo "  卸载: bash install.sh --uninstall"
echo ""
