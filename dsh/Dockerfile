# DeepSeek Harness (dsh) runtime image
# Installs the published npm CLI (@deepseek-ai/dsh) on Node.js 24.
ARG REGISTRY_PREFIX=docker.m.daocloud.io/library/
ARG NODE_VERSION=24-bookworm-slim
FROM ${REGISTRY_PREFIX}node:${NODE_VERSION}

ARG DSH_VERSION=0.2.1-rc.5
ARG PNPM_VERSION=12.16.1
ARG NPM_REGISTRY=https://registry.npmmirror.com
ARG APT_MIRROR=mirrors.aliyun.com
ARG UID=1000
ARG GID=1000

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    NPM_CONFIG_REGISTRY=${NPM_REGISTRY} \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    TZ=Asia/Shanghai

# Tools the agent commonly uses inside the workspace (shell, git, search, python).
RUN if [ -n "$APT_MIRROR" ]; then \
      sed -i "s|deb.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources; \
    fi \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git less openssh-client procps \
      python3 python3-pip python3-venv ripgrep tini tzdata unzip jq \
 && rm -rf /var/lib/apt/lists/*

# dsh itself + pnpm (used by `dsh plugin ... add <package>`)
RUN npm install -g "@deepseek-ai/dsh@${DSH_VERSION}" "pnpm@${PNPM_VERSION}" \
 && npm cache clean --force \
 && dsh --version

# Run as an unprivileged user whose uid/gid match the host owner of the mounted dirs.
# The base image ships user "node" with 1000:1000; reuse or remap it.
RUN set -eux; \
    existing_user="$(getent passwd "${UID}" | cut -d: -f1 || true)"; \
    if [ -n "$existing_user" ] && [ "$existing_user" != "dsh" ]; then userdel -r "$existing_user" || true; fi; \
    existing_group="$(getent group "${GID}" | cut -d: -f1 || true)"; \
    if [ -n "$existing_group" ] && [ "$existing_group" != "dsh" ]; then groupdel "$existing_group" || true; fi; \
    groupadd -g "${GID}" dsh; \
    useradd -l -m -u "${UID}" -g "${GID}" -s /bin/bash -d /home/dsh dsh; \
    mkdir -p /workspace; chown dsh:dsh /workspace

COPY --chmod=0755 entrypoint.sh /usr/local/bin/dsh-entrypoint

USER ${UID}:${GID}
ENV HOME=/home/dsh \
    DSH_HOME=/home/dsh/.dsh
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dsh-entrypoint"]
