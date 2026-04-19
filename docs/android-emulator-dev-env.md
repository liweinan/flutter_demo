# Android 模拟器与本仓库安装脚本说明

本文说明本项目中 **Android 模拟器** 所指的具体组件，以及 [`scripts/install-android-dev-env.sh`](../scripts/install-android-dev-env.sh) 会用到的工具与命令；脚本面向 **macOS**，依赖 **Homebrew**。

## 模拟器用的是什么？

使用的是 **Android SDK 自带的 Android Emulator**（Google 提供的 QEMU/KVM 虚拟设备运行时），不是第三方独立模拟器。虚拟设备实例在本地称为 **AVD（Android Virtual Device）**。

本脚本若未加 `--skip-avd`，会创建一个 AVD：

| 项目 | 值 |
|------|-----|
| **名称** | `flutter_demo_pi` |
| **设备外形** | Pixel 7（`avdmanager` 的 `--device pixel_7`） |
| **系统镜像** | `system-images;android-35;google_apis;arm64-v8a`（API 35，Google APIs，**arm64-v8a**，适合 Apple Silicon） |

启动时脚本末尾提示使用：

```bash
flutter emulators --launch flutter_demo_pi
```

其等价于在 `PATH` 已包含 `$ANDROID_SDK_ROOT/emulator` 时，由 Android SDK 的 `emulator` 可执行文件拉起该 AVD（Flutter 封装了同一套能力）。

与应用联调时，模拟器内访问宿主机上的 API 仍使用本项目默认的 **`10.0.2.2`**（见仓库根目录 `README.md` 与 `mobile/lib/main.dart`），与选用何种 AVD 名称无关。

## 脚本依赖的外部工具

| 工具 | 作用 |
|------|------|
| **Homebrew**（`brew`） | 安装 OpenJDK 17、Android SDK Command-line Tools（cask `android-commandlinetools`）。 |
| **OpenJDK 17** | Java 运行时；`sdkmanager` / `avdmanager` 需要。脚本将 `JAVA_HOME` 设为 `$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home`。 |
| **Android SDK Command-line Tools** | 提供 **`sdkmanager`**、**`avdmanager`**（位于 `$ANDROID_SDK_ROOT/cmdline-tools/latest/bin`）。 |
| **Flutter CLI**（可选） | 若已安装且未使用 `--skip-flutter-config`，脚本会执行 `flutter config --android-sdk`，让 Flutter 指向同一套 SDK。 |

默认 SDK 根目录（脚本内）：未设置 `ANDROID_SDK_ROOT` 时为 **`/opt/homebrew/share/android-commandlinetools`**（与 Homebrew cask 常见布局一致；Intel Mac 上 Homebrew 前缀可能为 `/usr/local`，可自行导出 `ANDROID_SDK_ROOT` 后再运行脚本）。

## 脚本中出现的命令与含义

以下顺序与脚本实际执行流程一致（节选核心命令）。

1. **`brew install openjdk@17`**（若尚未安装）  
   安装并供后续 `JAVA_HOME`、`PATH` 使用。

2. **`brew install --cask android-commandlinetools`**（若尚未安装）  
   安装命令行工具包，不包含 Android Studio IDE 界面。

3. **`yes | sdkmanager --sdk_root=... --licenses`**  
   非交互接受 SDK 许可（退出码 `141` 常与管道结束有关，脚本中有说明）。

4. **`sdkmanager --sdk_root=...` 安装组件**，包括：  
   - `platform-tools`（**`adb`** 等）  
   - `platforms;android-35`、`platforms;android-36`  
   - `build-tools;35.0.0`、`build-tools;36.1.0`、`build-tools;28.0.3`（脚本注释写明含 Flutter 3.41 等场景所需版本）  
   - `emulator`（**Android Emulator** 程序本体）  
   - `system-images;android-35;google_apis;arm64-v8a`（创建 AVD 用的系统镜像）

5. **`flutter config --android-sdk "$ANDROID_SDK_ROOT"`**  
   将 Flutter 的 Android SDK 路径指向本套安装（可用 `--skip-flutter-config` 跳过）。

6. **`avdmanager create avd`**（未使用 `--skip-avd` 且不存在同名 AVD 时）  
   创建名为 `flutter_demo_pi` 的 AVD，`--device pixel_7`，`--package` 指向上述 **API 35 / Google APIs / arm64-v8a** 镜像。已存在同名 AVD 则跳过创建。

脚本还会生成 **`scripts/android-env.snippet.sh`**，用于在 shell 中 `source` 以持久化 `JAVA_HOME`、`ANDROID_SDK_ROOT`、`PATH`（含 `cmdline-tools`、`platform-tools`、`emulator`）。

## 脚本参数与环境

| 方式 | 说明 |
|------|------|
| `--proxy URL` | 设置 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`，便于 `sdkmanager` 下载。 |
| `--skip-avd` | 不创建 AVD。 |
| `--skip-flutter-config` | 不执行 `flutter config --android-sdk`。 |
| 代理与 `sdkmanager` | 国内或受限网络下，可先起本机代理，再按脚本头部注释：`set -a && source scripts/host-proxy.env.example && set +a && ./scripts/install-android-dev-env.sh`。 |

## 安装完成后常用命令

| 命令 | 用途 |
|------|------|
| `source scripts/android-env.snippet.sh` | 加载脚本生成的环境变量（路径以本机仓库为准）。 |
| `flutter doctor -v` | 检查 Flutter 与 Android 工具链是否就绪。 |
| `flutter emulators` | 列出 Flutter 识别的模拟器。 |
| `flutter emulators --launch flutter_demo_pi` | 启动本脚本创建的 AVD（脚本结束时的推荐方式）。 |
| `adb devices` | 确认模拟器是否已连接（需 `platform-tools` 在 `PATH` 中）。 |
| `sdkmanager --list` | 查看已安装/可安装的 SDK 包（需完整环境变量）。 |

若未使用本脚本、而是通过 Android Studio 的 Device Manager 创建 AVD，也可正常联调；只需保证 **`flutter config --android-sdk`** 指向实际 SDK 路径，且模拟器访问宿主机 API 时仍使用 **`10.0.2.2:8080`**（与本项目默认一致）。
