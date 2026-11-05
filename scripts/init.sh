#!/usr/bin/env bash
# Prepare a fresh checkout: create .env and the bind-mounted directories.
#
# Usage:
#   ./scripts/init.sh                          # create .env from .env.example (if missing) + dirs
#   ./scripts/init.sh 203.0.113.10             # also set the public address (http://203.0.113.10/)
#   ./scripts/init.sh https://dsh.example.com/ # https URL also switches NGINX_MODE=https
#   ./scripts/init.sh http://203.0.113.10:8080/
set -euo pipefail
cd "$(dirname "$0")/.."

set_env() { # set_env KEY VALUE  — replace or append KEY=VALUE in .env
  local key="$1" val="$2" esc
  esc="$(printf '%s' "$val" | sed -e 's/[\\|&]/\\&/g')"
  if grep -q "^${key}=" .env; then
    sed -i.bak -e "s|^${key}=.*|${key}=${esc}|" .env && rm -f .env.bak
  else
    printf '%s=%s\n' "$key" "$val" >> .env
  fi
}
get_env() { grep -E "^$1=" .env | tail -n 1 | cut -d= -f2-; }

created=0
if [ ! -f .env ]; then
  cp .env.example .env
  created=1
  echo "created .env from .env.example"
  if [ "$(id -u)" -ne 0 ]; then
    set_env DSH_UID "$(id -u)"
    set_env DSH_GID "$(id -g)"
  fi
fi

if [ "$#" -gt 0 ]; then
  arg="$1"
  case "$arg" in
    http://*|https://*) url="$arg" ;;
    *) url="http://${arg}" ;;
  esac
  case "$url" in */) ;; *) url="${url}/" ;; esac
  scheme="${url%%://*}"
  authority="${url#*://}"; authority="${authority%%/*}"
  if [[ "$authority" == \[* ]]; then          # [IPv6]:port
    host="${authority%%]*}]"; rest="${authority#"$host"}"; port="${rest#:}"
  else
    host="${authority%%:*}"; port=""; [[ "$authority" == *:* ]] && port="${authority##*:}"
  fi
  set_env DSH_PUBLIC_URL "$url"
  set_env DSH_TRUSTED_HOSTS "$host"
  if [ "$scheme" = https ]; then
    set_env NGINX_MODE https
    [ -n "$port" ] && set_env HTTPS_PORT "$port"
  else
    set_env NGINX_MODE http
    [ -n "$port" ] && set_env HTTP_PORT "$port"
  fi
  echo "public URL: ${url}  (trusted host: ${host}, NGINX_MODE=${scheme})"
elif [ "$created" -eq 1 ]; then
  echo "NOTE: edit DSH_PUBLIC_URL / DSH_TRUSTED_HOSTS in .env, or rerun: $0 <public-host-or-url>"
fi

mkdir -p data/home workspace logs/nginx nginx/certs nginx/custom.d

# When run as root, hand the dsh-writable dirs to the container user.
if [ "$(id -u)" -eq 0 ]; then
  uid="$(get_env DSH_UID)"; gid="$(get_env DSH_GID)"
  chown -R "${uid:-1000}:${gid:-1000}" data/home workspace
fi

if [ "$(get_env NGINX_MODE)" = https ] && { [ ! -f nginx/certs/fullchain.pem ] || [ ! -f nginx/certs/privkey.pem ]; }; then
  echo "NOTE: NGINX_MODE=https needs nginx/certs/fullchain.pem and nginx/certs/privkey.pem"
fi

echo "done. next: docker compose up -d --build && ./scripts/show-url.sh"
