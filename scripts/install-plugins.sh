#!/usr/bin/env bash
# Install the lingshu dsh-memory plugin into the running dsh stack.
#
# Upstream: https://github.com/FuRongJun-1999/dsh-memory
# Follows the documented manual install (docs/ops/安装与前置.md 手工三步):
#   1. clone the source (pinned tag) and build it inside the container
#   2. dsh plugin --profile web add   (registers the plugin in the web profile)
#   3. write the profile cordis.patch.yml override + derive the write credential
#
# What ends up where (all inside the ./data/home bind mount, survives rebuilds):
#   ./data/home/src/dsh-memory                    plugin source + build
#   ./data/home/.dsh/profiles/web/                profile: dependency + config
#   ./data/home/.dsh/.dsh-memory/data/mdcg        memory store (md cognitive graph)
#   ./data/home/.mdcg/token                       bootstrap credential (autoinit)
#   .env: MDCG_TOKEN                              derived write credential
#
# Finish with `docker compose up -d dsh` to recreate the container with MDCG_TOKEN.
set -euo pipefail
cd "$(dirname "$0")/.."

DSH_MEMORY_VERSION="${DSH_MEMORY_VERSION:-v0.9.23}"          # tag == npm latest
SRC_HOST=./data/home/src/dsh-memory                           # host path
SRC_CT=/home/dsh/src/dsh-memory                               # same dir in the container
MDCG_ROOT_CT=/home/dsh/.dsh/.dsh-memory/data/mdcg             # memory store (upstream default)
PATCH_HOST=./data/home/.dsh/profiles/web/cordis.patch.yml
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

[ -f .env ] || { echo "error: no .env — run ./scripts/init.sh first" >&2; exit 1; }
[ -n "$(docker compose ps -q dsh)" ] || { echo "error: stack not running — run 'make up' first" >&2; exit 1; }

# --- 1. clone / update the plugin source (host git; the dir is bind-mounted) ---
if [ -d "$SRC_HOST/.git" ]; then
  echo "==> updating $SRC_HOST to $DSH_MEMORY_VERSION"
  git -C "$SRC_HOST" fetch --depth 1 origin "refs/tags/$DSH_MEMORY_VERSION"
  git -C "$SRC_HOST" checkout -q FETCH_HEAD
else
  echo "==> cloning dsh-memory $DSH_MEMORY_VERSION into $SRC_HOST"
  git clone --depth 1 --branch "$DSH_MEMORY_VERSION" \
    https://github.com/FuRongJun-1999/dsh-memory.git "$SRC_HOST"
fi

# --- 2. build inside the container -----------------------------------------
# The upstream build scripts invoke `python`; Debian only ships `python3`
# (PEP 394), so add a shim on PATH. npm install also triggers `prepare`,
# which builds lib/ via the same shim.
echo "==> building plugin in the container (npm install + tsc + ui)"
docker compose exec dsh sh -c '
  set -e
  mkdir -p /home/dsh/.local/bin
  ln -sf /usr/bin/python3 /home/dsh/.local/bin/python
  export PATH=/home/dsh/.local/bin:$PATH
  export npm_config_registry="'"$NPM_REGISTRY"'"
  cd '"$SRC_CT"'
  npm install --no-audit --no-fund
  npm run build
'

# --- 3. install into the web profile (dsh forwards to pnpm) ------------------
echo "==> dsh plugin --profile web add"
docker compose exec -e NPM_CONFIG_REGISTRY="$NPM_REGISTRY" dsh \
  dsh plugin --profile web add "$SRC_CT"

# --- 4. profile config override (idempotent) --------------------------------
if grep -q 'furongjun1999-dsh-memory' "$PATCH_HOST" 2>/dev/null; then
  echo "==> cordis.patch.yml already has the plugin override"
else
  echo "==> writing plugin override into $PATCH_HOST"
  # drop a pristine "[]" so the appended entry stays a valid top-level array
  sed -i '/^\[\]$/d' "$PATCH_HOST"
  cat >>"$PATCH_HOST" <<'YAML'

- id: furongjun1999-dsh-memory
  config:
    # 记忆唯一真源：md_cg 认知图。root 留空 = 用户级状态根
    # ~/.dsh/.dsh-memory/data/mdcg（在本部署的 bind mount ./data/home 内，持久化）
    mdcg:
      enabled: true
      root: ''
    identity: '灵枢'
    tools: 'core'          # cg/stg 两基元；可改 'brain' / 'all'
    env:
      # 写入凭据（fail-closed：不设则只读 guest）。派生自
      # /home/dsh/.mdcg/token 的引导 designer 令牌（收窄 ops/layers），
      # 经 .env 的 MDCG_TOKEN 注入宿主进程环境。
      MDCG_TOKEN: !!js process.env.MDCG_TOKEN
YAML
fi

# --- 5. derive the write credential (only if .env has none) ------------------
if [ -n "$(grep -E '^MDCG_TOKEN=' .env | tail -n 1 | cut -d= -f2-)" ]; then
  echo "==> MDCG_TOKEN already set in .env — keeping it"
else
  echo "==> deriving MDCG_TOKEN from the bootstrap credential"
  # The brain auto-initializes /home/dsh/.mdcg/token on first start; make sure
  # it exists (one-shot start with stdin closed is enough).
  docker compose exec dsh sh -c '
    [ -s /home/dsh/.mdcg/token ] || {
      cd '"$SRC_CT"'
      MDCG_ROOT='"$MDCG_ROOT_CT"' timeout 15 python3 -m md_cg.mcp_server </dev/null >/dev/null 2>&1 || true
    }
  '
  docker compose exec dsh sh -c '
    set -e
    cd '"$SRC_CT"'
    MDCG_ROOT='"$MDCG_ROOT_CT"' python3 -m md_cg.tokens derive \
      --token-file-in /home/dsh/.mdcg/token \
      --role designer --actor dsh-memory --clearance private \
      --ops-allow info,route,read,write,recent,goal,identity,whitebox,verify \
      --layers-allow knowledge,contextual,structural,self,goals,unresolved,rejected \
      > /home/dsh/.mdcg-derived.out 2>&1
    grep -oE "mdcg1\.[a-z]+\.tk_[a-f0-9]+\.[A-Za-z0-9_-]+" /home/dsh/.mdcg-derived.out | head -1 \
      > /home/dsh/.mdcg-derived-token
    [ -s /home/dsh/.mdcg-derived-token ]
  '
  token="$(cat data/home/.mdcg-derived-token)"
  rm -f data/home/.mdcg-derived.out data/home/.mdcg-derived-token
  if grep -q '^MDCG_TOKEN=' .env; then
    sed -i "s#^MDCG_TOKEN=.*#MDCG_TOKEN=${token}#" .env
  else
    printf 'MDCG_TOKEN=%s\n' "$token" >>.env
  fi
  echo "    written to .env (MDCG_TOKEN)"
fi

echo
echo "Done. Apply with:"
echo "  docker compose up -d dsh     # recreate with MDCG_TOKEN (issues a new login token)"
echo "Verify with:"
echo "  docker compose logs dsh | grep -i lingshu"
