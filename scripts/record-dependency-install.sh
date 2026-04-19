#!/usr/bin/env bash
# 记录本仓库依赖与环境安装过程的终端输出到 logs/ 目录。
# 用法:
#   ./scripts/record-dependency-install.sh                   # 仅采集环境与版本信息
#   ./scripts/record-dependency-install.sh --install         # 尝试通过 Homebrew 安装 cask，并执行 Flutter / uv(e2e) / cargo / docker build
#   ./scripts/record-dependency-install.sh --install-android # 额外执行 Android SDK/OpenJDK/emulator（见 scripts/install-android-dev-env.sh）
#   ./scripts/record-dependency-install.sh --install --install-android  # 两者都做
#
# 访问 Google SDK 受限时，安装 Android 组件前可先:
#   set -a && source scripts/host-proxy.env.example && set +a

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${LOG_DIR_OVERRIDE:-$REPO_ROOT/logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/dependency-install-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "日志文件: $LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "========================================"

echo ""
echo "--- 系统 ---"
command -v sw_vers >/dev/null 2>&1 && sw_vers || true
uname -a || true

echo ""
echo "--- Homebrew ---"
if command -v brew >/dev/null 2>&1; then
  brew --version
  echo "前缀: $(brew --prefix 2>/dev/null || echo '?')"
else
  echo "未检测到 brew；请先安装 Homebrew: https://brew.sh/"
fi

echo ""
echo "--- Docker ---"
(command -v docker >/dev/null 2>&1 && docker --version) || echo "docker 未安装或不在 PATH"
(command -v docker >/dev/null 2>&1 && docker compose version) || true

echo ""
echo "--- Flutter / Dart ---"
if command -v flutter >/dev/null 2>&1; then
  which flutter
  flutter --version
else
  echo "flutter 未在 PATH 中（可 brew install --cask flutter）"
fi

echo ""
echo "--- Rust（用于 server/）---"
if command -v rustc >/dev/null 2>&1; then
  rustc --version
  cargo --version
else
  echo "rustc 未安装（仅本地 cargo build 时需要；Docker 构建可不装）"
fi

echo ""
echo "--- uv（用于 e2e/）---"
if command -v uv >/dev/null 2>&1; then
  uv --version
else
  echo "uv 未安装（E2E 需要；可 brew install uv）"
fi

echo ""
echo "--- Android（路径仅作参考）---"
if [[ -n "${ANDROID_HOME:-}" ]]; then
  echo "ANDROID_HOME=$ANDROID_HOME"
else
  echo "ANDROID_HOME 未设置（安装 Android Studio 并完成向导后常为 \$HOME/Library/Android/sdk）"
fi

DO_INSTALL=false
DO_INSTALL_ANDROID=false
for arg in "$@"; do
  case "$arg" in
    --install) DO_INSTALL=true ;;
    --install-android) DO_INSTALL_ANDROID=true ;;
    --help|-h)
      echo "用法: $0 [--install] [--install-android]"
      exit 0
      ;;
  esac
done

if [[ "$DO_INSTALL" == true ]]; then
  echo ""
  echo "========================================"
  echo "--install: 尝试安装/更新依赖（需要网络与权限）"
  echo "========================================"

  if ! command -v brew >/dev/null 2>&1; then
    echo "跳过 brew 安装步骤：未找到 brew"
    exit 1
  fi

  install_cask_if_missing() {
    local cask_name="$1"
    if brew list --cask "$cask_name" >/dev/null 2>&1; then
      echo "Homebrew cask 已安装: $cask_name"
    else
      echo "安装 Homebrew cask: $cask_name"
      brew install --cask "$cask_name"
    fi
  }

  install_cask_if_missing flutter
  install_cask_if_missing android-studio

  echo ""
  echo "--- Flutter 诊断 ---"
  if command -v flutter >/dev/null 2>&1; then
    flutter doctor -v || true
    echo "提示: Android SDK 许可需交互接受，请另行执行: flutter doctor --android-licenses"
  else
    echo "flutter 仍未可用，请检查 PATH（例如 /opt/homebrew/bin）"
  fi

  echo ""
  echo "--- Flutter 项目依赖（mobile/）---"
  if [[ -f "$REPO_ROOT/mobile/pubspec.yaml" ]]; then
    (cd "$REPO_ROOT/mobile" && flutter pub get)
    (cd "$REPO_ROOT/mobile" && flutter pub outdated) || true
  else
    echo "未找到 mobile/pubspec.yaml"
  fi

  echo ""
  echo "--- Rust 服务端依赖解析（可选）---"
  if [[ -f "$REPO_ROOT/server/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
    (cd "$REPO_ROOT/server" && cargo fetch)
  else
    echo "跳过 cargo fetch（无 cargo 或无 server/Cargo.toml）"
  fi

  echo ""
  echo "--- uv + E2E（Python）---"
  if [[ -f "$REPO_ROOT/e2e/pyproject.toml" ]]; then
    if ! command -v uv >/dev/null 2>&1; then
      echo "安装 uv（brew install uv）"
      brew install uv
    fi
    if command -v uv >/dev/null 2>&1; then
      (cd "$REPO_ROOT/e2e" && uv sync)
    else
      echo "uv 仍不可用，跳过 e2e 环境同步"
    fi
  else
    echo "未找到 e2e/pyproject.toml，跳过"
  fi

  echo ""
  echo "--- Docker 镜像构建（可选，需 Docker 与网络）---"
  if command -v docker >/dev/null 2>&1 && [[ -f "$REPO_ROOT/docker-compose.yml" ]]; then
    (cd "$REPO_ROOT" && docker compose build) || echo "docker compose build 失败，请查看上方输出"
  else
    echo "跳过 docker compose build"
  fi
fi

if [[ "$DO_INSTALL_ANDROID" == true ]]; then
  echo ""
  echo "========================================"
  echo "--install-android: OpenJDK + sdkmanager + Flutter android-sdk + AVD"
  echo "========================================"
  if [[ -x "$SCRIPT_DIR/install-android-dev-env.sh" ]]; then
    bash "$SCRIPT_DIR/install-android-dev-env.sh"
  else
    echo "未找到可执行脚本: $SCRIPT_DIR/install-android-dev-env.sh"
    exit 1
  fi
fi

echo ""
echo "========================================"
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "完整记录已写入: $LOG_FILE"
echo "========================================"
