#!/usr/bin/env bash
# Launch `dsh web` behind the Nginx container.
#
# dsh shares Nginx's network namespace (docker compose: network_mode: service:nginx),
# so it listens only on 127.0.0.1 and is reachable exclusively through Nginx.
set -euo pipefail

: "${DSH_PORT:=3080}"
: "${DSH_PUBLIC_URL:=}"
: "${DSH_TRUSTED_HOSTS:=}"
: "${DSH_EXTRA_ARGS:=}"

for d in "${HOME}" /workspace; do
  if [ ! -w "$d" ]; then
    echo "[entrypoint] ERROR: $d is not writable by uid $(id -u). On the host run:" >&2
    echo "  sudo chown -R $(id -u):$(id -g) ./data/home ./workspace" >&2
    exit 1
  fi
done
mkdir -p "${DSH_HOME}"

# Custom subcommand passthrough, e.g. `docker compose run --rm dsh dsh --version`
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

args=(web --no-open --host 127.0.0.1 --port "${DSH_PORT}")

if [ -z "${DSH_TRUSTED_HOSTS}" ]; then
  echo "[entrypoint] WARNING: DSH_TRUSTED_HOSTS is empty; browsers on other machines will get 403 on every API call." >&2
fi

if [ -n "${DSH_PUBLIC_URL}" ]; then
  args+=(--public-url "${DSH_PUBLIC_URL}")
fi

# Comma- or space-separated list of browser-visible authorities (host or host:port).
for h in ${DSH_TRUSTED_HOSTS//,/ }; do
  args+=(--trusted-host "$h")
done

# shellcheck disable=SC2206
extra=(${DSH_EXTRA_ARGS})

echo "[entrypoint] DSH_HOME=${DSH_HOME} cwd=$(pwd)"
echo "[entrypoint] exec dsh ${args[*]} ${extra[*]:-}"
exec dsh "${args[@]}" "${extra[@]}"
