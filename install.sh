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
MARKETPLACE="local"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE}"

# ---- 路径 ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
CLAUDE_DIR="${HOME}/.claude"
PLUGINS_DIR="${CLAUDE_DIR}/plugins"
INSTALLED_JSON="${PLUGINS_DIR}/installed_plugins.json"
SETTINGS_JSON="${CLAUDE_DIR}/settings.json"

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- 查找 Python ----
find_python() {
  # python 在前：Windows 上 python3 经常是 App Store 的假 stub
  for py in python python3; do
    if command -v "$py" >/dev/null 2>&1 && "$py" -c "print('ok')" >/dev/null 2>&1; then
      echo "$py"
      return
    fi
  done
  echo ""
}

# ---- 转为原生路径（Windows → cygpath -w，其他系统保持不变）----
to_native_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
  else
    echo "$p"
  fi
}

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

# ==============================================================================
# 卸载
# ==============================================================================
do_uninstall() {
  echo ""
  echo "=== 卸载 ${PLUGIN_NAME} ==="
  echo ""

  PYTHON=$(find_python)
  if [ -z "${PYTHON}" ]; then
    log_error "未找到 Python，请手动编辑以下文件删除 ${PLUGIN_KEY}:"
    log_error "  ${INSTALLED_JSON}"
    log_error "  ${SETTINGS_JSON}"
    exit 1
  fi

  NATIVE_INSTALLED_JSON=$(to_native_path "${INSTALLED_JSON}")
  NATIVE_SETTINGS_JSON=$(to_native_path "${SETTINGS_JSON}")

  PYTHONIOENCODING=utf-8 "${PYTHON}" -c "
import json, sys

plugin_key = sys.argv[1]
installed_json = sys.argv[2]
settings_json = sys.argv[3]

# 从 installed_plugins.json 移除
try:
    with open(installed_json, 'r') as f:
        data = json.load(f)
    if 'plugins' in data:
        removed = data['plugins'].pop(plugin_key, None)
        if removed:
            print(f'  ✓ 已从 installed_plugins.json 移除 {plugin_key}')
        else:
            print(f'  [SKIP] {plugin_key} 不在 installed_plugins.json 中')
    with open(installed_json, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
except (FileNotFoundError, json.JSONDecodeError) as e:
    print(f'  [SKIP] installed_plugins.json: {e}')

# 从 settings.json 移除
try:
    with open(settings_json, 'r') as f:
        data = json.load(f)
    if 'enabledPlugins' in data and plugin_key in data['enabledPlugins']:
        del data['enabledPlugins'][plugin_key]
        with open(settings_json, 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        print(f'  ✓ 已从 settings.json 移除 {plugin_key}')
    else:
        print(f'  [SKIP] {plugin_key} 不在 settings.json 中')
except (FileNotFoundError, json.JSONDecodeError) as e:
    print(f'  [SKIP] settings.json: {e}')
" "${PLUGIN_KEY}" "${NATIVE_INSTALLED_JSON}" "${NATIVE_SETTINGS_JSON}"

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
echo "  配置文件: ${INSTALLED_JSON}"
echo "            ${SETTINGS_JSON}"
echo ""

# ---- 检查 Python ----
PYTHON=$(find_python)
if [ -z "${PYTHON}" ]; then
  log_error "未找到 Python (python3 或 python)"
  log_error "请安装 Python 后重试"
  exit 1
fi
log_info "Python: ${PYTHON}"

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

# ---- 获取 commit SHA ----
COMMIT_SHA=$(git -C "${PROJECT_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")
log_info "Commit: ${COMMIT_SHA}"

# ---- 转为原生路径 ----
NATIVE_PROJECT_DIR=$(to_native_path "${PROJECT_DIR}")
NATIVE_INSTALLED_JSON=$(to_native_path "${INSTALLED_JSON}")
NATIVE_SETTINGS_JSON=$(to_native_path "${SETTINGS_JSON}")

INSTALL_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# ---- 注册并启用插件 ----
log_info "注册插件..."

# 注意：所有值通过 sys.argv 传入 Python，不嵌入到代码字符串中。
# 这样可以避免 shell 转义问题（之前 sed 's/\\/\\\\/g' 导致路径中的反斜杠被重复转义）。
PYTHONIOENCODING=utf-8 "${PYTHON}" -c "
import json, sys

plugin_key      = sys.argv[1]
plugin_version  = sys.argv[2]
install_path    = sys.argv[3]   # 项目根目录（原生路径）
install_time    = sys.argv[4]
commit_sha      = sys.argv[5]
installed_json  = sys.argv[6]
settings_json   = sys.argv[7]

# === installed_plugins.json ===
try:
    with open(installed_json, 'r') as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {'version': 2, 'plugins': {}}

if 'version' not in data:
    data['version'] = 2
if 'plugins' not in data:
    data['plugins'] = {}

data['plugins'][plugin_key] = [{
    'scope': 'user',
    'installPath': install_path,
    'version': plugin_version,
    'installedAt': install_time,
    'lastUpdated': install_time,
    'gitCommitSha': commit_sha
}]

with open(installed_json, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f'  ✓ 已注册到 installed_plugins.json')

# === settings.json ===
try:
    with open(settings_json, 'r') as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

if 'enabledPlugins' not in data:
    data['enabledPlugins'] = {}

data['enabledPlugins'][plugin_key] = True

with open(settings_json, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(f'  ✓ 已在 settings.json 中启用')
" "${PLUGIN_KEY}" "${PLUGIN_VERSION}" "${NATIVE_PROJECT_DIR}" "${INSTALL_TIME}" "${COMMIT_SHA}" "${NATIVE_INSTALLED_JSON}" "${NATIVE_SETTINGS_JSON}"

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
echo "  重启 Claude Code 后生效"
echo "  卸载: bash install.sh --uninstall"
echo ""
