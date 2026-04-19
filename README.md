# Flutter Android Demo + Docker（PostgreSQL）

Android 客户端（Flutter）调用宿主机上由 Docker Compose 启动的 Rust API，API 读取 PostgreSQL。Flutter 仅作原生壳与网络演示，后续可接入 WebView + React（TypeScript）或扩展 Rust 服务。

## 前提

- macOS，已安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)（或兼容的 `docker compose`）。
- Flutter 与 Android 工具链（见下文「macOS：Flutter 与模拟器」）。

## 启动后端

在仓库根目录：

```bash
docker compose up -d --build
```

检查 API（在 Mac 本机）：

```bash
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/db-version
curl -s http://127.0.0.1:8080/greeting
```

PostgreSQL 映射到宿主机端口 **5433**（容器内仍为5432），避免与本机已有 Postgres 冲突。连接串示例：

`postgresql://demo:demo@127.0.0.1:5433/demo`

停止并删除容器（保留数据卷则不要加 `-v`）：

```bash
docker compose down
```

## 启动 Flutter（Android 模拟器）

1. 确保模拟器已启动，且 **先** 已执行 `docker compose up`。
2. Android 模拟器访问宿主机上映射的端口须使用 **`http://10.0.2.2:8080`**，应用默认已配置该地址。
3. 在项目内：

```bash
cd mobile
flutter pub get
flutter run
```

自定义 API 地址（可选）：

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

**真机 USB调试**：可将 USB 端口转发到本机，例如：

```bash
adb reverse tcp:8080 tcp:8080
```

然后将 `API_BASE_URL` 设为 `http://127.0.0.1:8080` 后运行。

## 目录说明

| 路径 | 说明 |
|------|------|
| `docker-compose.yml` | `db`（PostgreSQL）、`api`（Rust） |
| `db/init/` | 首次初始化数据库的 SQL |
| `server/` | Axum + `tokio-postgres`，路由 `/health`、`/db-version`、`/greeting` |
| `mobile/` | Flutter Android 工程 |

## macOS：Flutter 与 Android 模拟器

### 安装 Flutter

已使用 Homebrew 时：

```bash
brew install --cask flutter
```

或按官方文档：[Install Flutter on macOS](https://docs.flutter.dev/get-started/install/macos)。

将 `flutter` 加入 `PATH` 后执行：

```bash
flutter doctor -v
```

### Android SDK 与模拟器

本仓库已通过 Homebrew 安装 **Android Studio**（`brew install --cask android-studio`）。首次使用仍需在本机完成 SDK 与虚拟设备配置：

1. 打开 **Android Studio**，按引导完成 **Setup Wizard**（会下载 Android SDK，默认路径多为 `~/Library/Android/sdk`）。
2. **SDK Manager**：确认已安装 Android SDK、**SDK Command-line Tools**、**Platform Tools**。
3. **Device Manager**：创建 **AVD**（Apple Silicon 选择 **arm64-v8a** 系统镜像，如 API 34/35）。
4. 若 Flutter 找不到 SDK，可显式指定（路径以本机为准）：

```bash
flutter config --android-sdk "$HOME/Library/Android/sdk"
```

5. 接受许可：

```bash
flutter doctor --android-licenses
```

### 联调顺序建议

1. `docker compose up -d --build`
2. `curl http://127.0.0.1:8080/health` 成功
3. 启动模拟器，再 `cd mobile && flutter run`

## 常见问题

- **模拟器无法访问 API**：确认使用 `10.0.2.2` 而非 `127.0.0.1`；确认本机 `8080` 未被占用。
- **明文 HTTP 失败**：`mobile/android/app/src/main/AndroidManifest.xml` 中已为本地调试开启 `usesCleartextTraffic`；生产环境应使用 HTTPS。
- **首次构建 Rust 镜像较慢**：依赖编译需要时间，后续可利用 Docker 层缓存。
- **端口 5433 被占用**：修改 `docker-compose.yml` 中 `db` 的 `ports` 映射，并同步调整本机连接串。
