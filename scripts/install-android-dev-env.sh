#!/usr/bin/env bash
# macOS：用 Homebrew 安装 OpenJDK 17、Android SDK 命令行工具，并通过 sdkmanager 安装
# platform-tools / 多版本 build-tools / emulator / 系统镜像，配置 Flutter android-sdk，
# 并创建 Pixel 类 AVD（默认名称 flutter_demo_pi）。
#
# 在中国大陆或访问 Google 受限时，请先启动本机代理（如 Clash 7890），再：
#   set -a && source scripts/host-proxy.env.example && set +a && ./scripts/install-android-dev-env.sh
#
# 可选参数：
#   --proxy URL     覆盖 HTTP(S)_PROXY（默认读环境变量）
#   --skip-avd      不创建模拟器 AVD
#   --skip-flutter-config   不执行 flutter config --android-sdk
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKIP_AVD=false
SKIP_FLUTTER_CONFIG=false
PROXY_CLI=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --proxy)
      PROXY_CLI="${2:-}"
      shift 2
      ;;
    --skip-avd) SKIP_AVD=true; shift ;;
    --skip-flutter-config) SKIP_FLUTTER_CONFIG=true; shift ;;
    -h|--help)
      grep '^#' "$0" | head -22 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

if [[ -n "${PROXY_CLI}" ]]; then
  export HTTP_PROXY="$PROXY_CLI"
  export HTTPS_PROXY="$PROXY_CLI"
  export ALL_PROXY="$PROXY_CLI"
fi

# 与 curl/apt 兼容的小写代理变量
export http_proxy="${HTTP_PROXY:-}"
export https_proxy="${HTTPS_PROXY:-${HTTP_PROXY:-}}"
export no_proxy="${NO_PROXY:-localhost,127.0.0.1}"

if ! command -v brew >/dev/null 2>&1; then
  echo "需要 Homebrew: https://brew.sh/"
  exit 1
fi

echo ">>> 安装 OpenJDK 17（formula，无需 sudo 图形安装器）"
brew list openjdk@17 >/dev/null 2>&1 || brew install openjdk@17

JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

echo ">>> 安装 Android SDK Command-line Tools（Homebrew cask）"
brew list --cask android-commandlinetools >/dev/null 2>&1 || brew install --cask android-commandlinetools

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
export ANDROID_SDK_ROOT
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"

echo ">>> 接受 SDK 许可"
set +e
yes 2>/dev/null | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses
LICENSE_RC=$?
set -e
if [[ "$LICENSE_RC" -ne 0 ]] && [[ "$LICENSE_RC" -ne 141 ]]; then
  echo "sdkmanager --licenses 退出码 $LICENSE_RC（141 常为 yes 管道 SIGPIPE，可忽略若下方安装成功）"
fi

echo ">>> 安装 SDK 组件（含 Flutter 3.41 所需的 API 36 / build-tools 28.0.3）"
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "platforms;android-35" \
  "platforms;android-36" \
  "build-tools;35.0.0" \
  "build-tools;36.1.0" \
  "build-tools;28.0.3" \
  "emulator" \
  "system-images;android-35;google_apis;arm64-v8a"

echo ">>> flutter config --android-sdk"
if [[ "$SKIP_FLUTTER_CONFIG" != true ]] && command -v flutter >/dev/null 2>&1; then
  flutter config --android-sdk "$ANDROID_SDK_ROOT"
else
  echo "跳过 flutter config（未找到 flutter 或指定 --skip-flutter-config）。可稍后执行:"
  echo "  flutter config --android-sdk \"$ANDROID_SDK_ROOT\""
fi

if [[ "$SKIP_AVD" != true ]]; then
  echo ">>> 创建 AVD（若已存在则跳过创建）"
  if command -v avdmanager >/dev/null 2>&1 && ! avdmanager list avd 2>/dev/null | grep -q 'Name: flutter_demo_pi'; then
    printf 'no\n' | avdmanager create avd \
      --force \
      --name flutter_demo_pi \
      --package 'system-images;android-35;google_apis;arm64-v8a' \
      --device pixel_7
  else
    echo "AVD flutter_demo_pi 已存在或未安装 avdmanager"
  fi
fi

SNIPPET_FILE="$SCRIPT_DIR/android-env.snippet.sh"
echo ">>> 写入终端环境片段: $SNIPPET_FILE"
cat > "$SNIPPET_FILE" << EOF
# 由 scripts/install-android-dev-env.sh 生成，可在 ~/.zshrc 末行添加: source $REPO_ROOT/scripts/android-env.snippet.sh
export JAVA_HOME="$JAVA_HOME"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="\$ANDROID_SDK_ROOT"
export PATH="\$JAVA_HOME/bin:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$ANDROID_SDK_ROOT/emulator:\$PATH"
EOF

echo ""
echo "完成。建议新开终端执行: source \"$SNIPPET_FILE\""
echo "运行模拟器: flutter emulators --launch flutter_demo_pi"
echo "宿主机代理下使用 sdkmanager 前可: set -a && source $REPO_ROOT/scripts/host-proxy.env.example && set +a"
