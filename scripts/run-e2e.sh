#!/usr/bin/env bash
# 运行 Selenium E2E（依赖 uv；需先有 API：`docker compose up`，默认 http://127.0.0.1:8080）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v uv >/dev/null 2>&1; then
  echo "未找到 uv。安装: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  echo "或: brew install uv" >&2
  exit 1
fi

cd "$ROOT/e2e"
uv sync
exec uv run pytest tests/ "$@"
