#!/usr/bin/env bash
# End-to-end smoke test of a running stack, through nginx:
# startup-token login, cookie auth, Host fence, WebSocket upgrade, log masking.
#
# Usage: ./scripts/smoke-test.sh      (reads NGINX_MODE / ports / trusted host from .env)
set -euo pipefail
cd "$(dirname "$0")/.."

get_env() { grep -E "^$1=" .env | tail -n 1 | cut -d= -f2-; }
mode="$(get_env NGINX_MODE)"; mode="${mode:-http}"
http_port="$(get_env HTTP_PORT)"; http_port="${http_port:-80}"
https_port="$(get_env HTTPS_PORT)"; https_port="${https_port:-443}"
trusted="$(get_env DSH_TRUSTED_HOSTS)"; trusted="${trusted%%,*}"; trusted="${trusted// /}"
trusted="${trusted:-127.0.0.1}"

if [ "$mode" = https ]; then
  base="https://127.0.0.1:${https_port}"
else
  base="http://127.0.0.1:${http_port}"
fi
H="Host: ${trusted}"
c() { curl -sk -o /dev/null -m 10 -w '%{http_code}' "$@" || true; }

fail=0
check() { # check NAME EXPECTED ACTUAL
  if [[ "$3" =~ ^($2)$ ]]; then printf '  PASS  %-42s %s\n' "$1" "$3"
  else printf '  FAIL  %-42s got %s, want %s\n' "$1" "$3" "$2"; fail=1; fi
}

echo "smoke test: ${base} (Host: ${trusted}, mode: ${mode})"

url="$(./scripts/show-url.sh)"
token="${url#*token=}"
check "login URL printed with token" "yes" "$([ -n "$token" ] && [ "$token" != "$url" ] && echo yes || echo no)"
check "login URL uses DSH_PUBLIC_URL" "yes" "$([[ "$url" == "$(get_env DSH_PUBLIC_URL)"* ]] && echo yes || echo no)"

check "GET / without token -> 401" "401" "$(c -H "$H" "${base}/")"

hdr="$(curl -sk -o /dev/null -D - -m 10 -H "$H" "${base}/?token=${token}" || true)"
status="$(printf '%s' "$hdr" | head -n 1 | awk '{print $2}')"
check "token exchange -> redirect" "30[23]" "$status"
cookie="$(printf '%s' "$hdr" | grep -i '^set-cookie:' | head -n 1 | sed -E 's/^[Ss]et-[Cc]ookie: *([^;]*).*/\1/' | tr -d '\r' || true)"
check "token exchange sets session cookie" "yes" "$([ -n "$cookie" ] && echo yes || echo no)"
if [ "$mode" = https ]; then
  check "session cookie has Secure flag" "yes" \
    "$(printf '%s' "$hdr" | grep -i '^set-cookie:' | grep -qi '; *secure' && echo yes || echo no)"
fi

check "API without cookie -> 401" "401" "$(c -X POST -H "$H" "${base}/api/smoke-test")"
api_code="$(c -X POST -H "$H" -b "$cookie" "${base}/api/smoke-test")"
check "API with cookie is not 401/403" "yes" "$([[ ! "$api_code" =~ ^(401|403|000)$ ]] && echo yes || echo "no ($api_code)")"
check "untrusted Host -> 403" "403" "$(c -X POST -H 'Host: untrusted.invalid' -b "$cookie" "${base}/api/smoke-test")"
# Force HTTP/1.1: over TLS curl negotiates HTTP/2, which has no Upgrade mechanism.
# Browsers do the same, since nginx does not offer WebSocket over HTTP/2 (RFC 8441).
check "WebSocket upgrade -> 101" "101" "$(c --http1.1 -m 5 -H "$H" -b "$cookie" \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "${base}/api/remote.mux")"

if [ "$mode" = https ]; then
  check "HTTP redirects to HTTPS -> 301" "301" "$(c -H "$H" "http://127.0.0.1:${http_port}/")"
fi

check "access log masks token" "yes" \
  "$(grep -q 'token=\*\*\*' logs/nginx/access.log && ! grep -qF "$token" logs/nginx/access.log && echo yes || echo no)"

if [ "$fail" -ne 0 ]; then echo "smoke test FAILED"; exit 1; fi
echo "smoke test passed"
