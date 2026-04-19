# -------- React（Vite）静态资源 --------
FROM node:22-bookworm AS frontend-builder
WORKDIR /build
COPY frontend/package.json ./
COPY frontend/package-lock.json* ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# -------- Rust API --------
# 构建阶段需 Cargo ≥1.85（依赖 crate 声明 edition2024）；使用 rust:1-bookworm = 当前 stable 1.x
FROM rust:1-bookworm AS builder
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY
# apt / rustup / cargo 常见同时认大小写；构建阶段注入 compose 传入的代理
ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV ALL_PROXY=${ALL_PROXY}
ENV NO_PROXY=${NO_PROXY}
ENV http_proxy=${HTTP_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV no_proxy=${NO_PROXY}
ENV CARGO_NET_RETRY=10

# 可选：换 Debian 源，减轻 deb.debian.org CDN 502（可与代理二选一或一起用）
ARG APT_MIRROR=
ARG APT_MIRROR_SECURITY=
RUN set -eux; \
    if [ -n "${APT_MIRROR}" ]; then \
      echo "APT_MIRROR=${APT_MIRROR}"; \
      if [ -f /etc/apt/sources.list ]; then \
        sed -i "s#http://deb.debian.org/debian#${APT_MIRROR}#g; s#https://deb.debian.org/debian#${APT_MIRROR}#g" /etc/apt/sources.list; \
      fi; \
      for f in /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list; do \
        [ -f "$f" ] || continue; \
        sed -i "s#http://deb.debian.org/debian#${APT_MIRROR}#g; s#https://deb.debian.org/debian#${APT_MIRROR}#g" "$f" || true; \
      done; \
    fi; \
    if [ -n "${APT_MIRROR_SECURITY}" ]; then \
      echo "APT_MIRROR_SECURITY=${APT_MIRROR_SECURITY}"; \
      for f in /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list /etc/apt/sources.list; do \
        [ -f "$f" ] || continue; \
        sed -i "s#http://security.debian.org/debian-security#${APT_MIRROR_SECURITY}#g; s#https://security.debian.org/debian-security#${APT_MIRROR_SECURITY}#g" "$f" || true; \
      done; \
    fi

# 链接 libpq：仅此阶段 apt；代理走上方 ENV；502 时对 apt-get update 整体重试
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    printf '%s\n' \
      'Acquire::Retries "12";' \
      'Acquire::http::Timeout "120";' \
      'Acquire::https::Timeout "120";' \
      > /etc/apt/apt.conf.d/99-docker; \
    if [ -n "${HTTP_PROXY:-}" ]; then \
      printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "${HTTP_PROXY}" "${HTTPS_PROXY:-${HTTP_PROXY}}" \
        >> /etc/apt/apt.conf.d/99-docker; \
    fi; \
    attempt=1; max=10; \
    while [ "$attempt" -le "$max" ]; do \
      apt-get update && break; \
      echo "apt-get update failed (${attempt}/${max}), retry..." >&2; \
      sleep $((attempt * 4)); \
      attempt=$((attempt + 1)); \
    done; \
    apt-get install -y --no-install-recommends libpq5 ca-certificates; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server/Cargo.toml server/Cargo.lock ./
COPY server/src ./src
RUN cargo build --release

# 将 ldd 所需 .so 拷入固定目录，供 slim 运行时一次性 COPY（最终镜像无 apt）
RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in aarch64) T=aarch64-linux-gnu;; x86_64) T=x86_64-linux-gnu;; *) echo "unsupported arch: $ARCH" >&2; exit 1;; esac; \
    DEST="/bundle/usr/lib/${T}"; \
    mkdir -p "${DEST}"; \
    ldd /app/target/release/demo-api | awk '/=>/ {print $3}' | grep '^/' | sort -u | while read -r f; do cp -L "${f}" "${DEST}/"; done; \
    mkdir -p /bundle/etc/ssl/certs; \
    cp /etc/ssl/certs/ca-certificates.crt /bundle/etc/ssl/certs/

FROM debian:bookworm-slim
COPY --from=frontend-builder /build/dist /srv/ui
COPY --from=builder /bundle/usr/lib/ /usr/lib/
COPY --from=builder /bundle/etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /app/target/release/demo-api /usr/local/bin/demo-api
RUN ldconfig
ENV STATIC_UI_ROOT=/srv/ui
EXPOSE 8080
CMD ["demo-api"]
