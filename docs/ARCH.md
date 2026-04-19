# 架构说明（ARCH）

本文档描述本仓库各组件使用的框架、运行时与工具，依据仓库内实际配置文件与代码整理。

## 1. 仓库结构

| 目录 | 职责 |
|------|------|
| `mobile/` | Flutter 移动应用（WebView 嵌入前端 UI） |
| `frontend/` | React 单页应用，由 Vite 构建为静态资源 |
| `server/` | Rust HTTP API，并可托管 `/ui` 静态站点 |
| `db/` | PostgreSQL 初始化脚本（供 Compose 挂载） |

## 2. 移动端：`mobile/`

- **语言与 SDK**：Dart，SDK 约束见 `mobile/pubspec.yaml`（`environment.sdk: ^3.11.5`）。
- **UI 框架**：Flutter（Material Design 3，`uses-material-design: true`）。
- **依赖**：
  - `cupertino_icons`：图标资源。
  - `webview_flutter`：内嵌 WebView，加载由后端提供的 React 页面（路径与 Vite `base` 及 `REACT_UI_URL` / `API_BASE_URL` 等编译期变量配合）。
- **质量与规范**：`flutter_lints` + `analysis_options.yaml`（继承官方推荐规则集）。
- **测试**：`flutter_test`（开发依赖）。

## 3. 前端：`frontend/`

- **运行时库**：React 19（`react`、`react-dom`）。
- **语言**：TypeScript（`typescript` ~5.8，严格模式见 `frontend/tsconfig.json`）。
- **构建与开发服务器**：Vite 6（`vite`），React 插件 `@vitejs/plugin-react`。
- **模块与产物**：`package.json` 中 `"type": "module"`；构建输出由 Rust 服务在路径前缀 `/ui` 下提供静态文件服务，因此 Vite 配置 `base: '/ui/'`；本地 `npm run dev` 时通过 `vite` 的 `server.proxy` 将 `/health`、`/db-version`、`/greeting` 转发到本机 API（默认 `8080`），便于联调。

## 4. 服务端：`server/`

- **语言与工具链**：Rust，`edition = "2021"`（`server/Cargo.toml`）。
- **异步运行时**：Tokio（`features = ["full"]`）。
- **Web 框架**：Axum 0.7（含 JSON 支持）。
- **HTTP 中间件**：`tower-http`（CORS、HTTP 追踪 `TraceLayer`、静态目录 `ServeDir`）。
- **序列化**：`serde` / `serde_json`。
- **数据库**：`tokio-postgres` + `NoTls`（连接串来自环境变量 `DATABASE_URL`）。
- **可观测性**：`tracing`、`tracing-subscriber`（日志级别可由 `RUST_LOG` 等环境过滤）。
- **对外行为**：监听地址由 `BIND_ADDR` 控制（默认 `0.0.0.0:8080`）；若 `STATIC_UI_ROOT` 指向的目录存在，则将构建后的前端挂在 `/ui`；提供 `/health`、`/db-version`、`/greeting` 等路由（详见 `server/src/main.rs`）。

## 5. 数据与基础设施

- **数据库**：PostgreSQL 15（镜像 `postgres:15-alpine`，见 `docker-compose.yml`）。
- **编排**：Docker Compose，服务 `db`（健康检查 + 数据卷 `pgdata`）与 `api`（根据 `server/Dockerfile` 构建）。

## 6. 容器镜像构建：`server/Dockerfile`

多阶段构建，概括如下：

1. **frontend-builder**：基于 `node:22-bookworm`，执行 `npm install` 与 `npm run build`，产出前端静态文件。
2. **builder**：基于 `rust:1-bookworm`，链接 `libpq`，`cargo build --release` 生成 `demo-api`；将运行时所需动态库与 CA 证书打包到固定目录。
3. **最终镜像**：`debian:bookworm-slim`，拷贝静态 UI、`demo-api` 与依赖库，暴露 `8080`，入口为 `demo-api`。

构建阶段支持通过 build args 注入 `HTTP_PROXY` / `HTTPS_PROXY` / `APT_MIRROR` 等，以适配网络与镜像源环境。

## 7. 组件协作关系（概念）

- **浏览器或 Flutter WebView**：访问后端上的 React 应用（路径前缀 `/ui/`），并与同一主机的 REST API 交互。
- **本地开发**：可在 `frontend` 运行 Vite 开发服务器，API 由本机或 Docker 中的 Rust 服务提供；Vite 将部分 API 路径代理到后端。
- **一体化部署**：单容器内同时包含 Rust 二进制与前端 `dist`，由 Axum 提供 API 与静态资源。

## 8. 命令行工具链（开发时常用）

| 领域 | 工具 |
|------|------|
| Flutter / Dart | Flutter CLI、`flutter pub`、`dart analyze` |
| 前端 | `npm` / Node 22（与 Dockerfile 一致）、`npm run dev` / `build` |
| 后端 | `cargo`、`rustc`（stable，需满足项目依赖的 Edition / 依赖版本要求） |
| 容器 | Docker Engine、Docker Compose |

---

若依赖版本升级，请以各目录下的 `pubspec.yaml`、`package.json`、`Cargo.toml` 及锁文件为准。
