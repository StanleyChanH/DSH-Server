#!/usr/bin/env bash
# Print the most recent dsh login URL (contains the per-process startup token).
# Share it only with intended users: anyone holding it becomes the owner session.
set -euo pipefail
cd "$(dirname "$0")/.."
url="$(docker compose logs --no-log-prefix dsh 2>/dev/null | grep -Eo 'https?://[^ ]*[?&]token=[^ ]+' | tail -n 1 || true)"
if [ -z "$url" ]; then
  echo "未找到登录链接，dsh 可能尚未启动完成。查看日志：docker compose logs -f dsh" >&2
  exit 1
fi
echo "$url"
