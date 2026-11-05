# Changelog

本项目的所有重要变更记录在此文件中。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Fixed

- CI smoke (https) 失败：TLS 下 curl 协商到 HTTP/2，WebSocket 升级头被丢弃（404）。冒烟测试的 WebSocket 检查改为强制 HTTP/1.1，与浏览器行为一致；Nginx 配置本身无问题
- CI lint 失败（DL3006）：原因是 hadolint-action v3.1.0 内置的 hadolint v2.12.0 无法解析 `FROM ${REGISTRY_PREFIX}${NODE_IMAGE}` 中的标签；升级到 hadolint v2.15.1 后通过，Dockerfile 与构建参数保持不变

### Changed

- CI 改为直接执行 `make lint`；shellcheck / hadolint 镜像版本固定在 `.github/lint/compose.yml`，由 Dependabot 跟踪更新，本地与 CI 使用同一版本
- hadolint 以文件路径方式运行，报错带 `dsh/Dockerfile:<行号>`
- `actions/checkout` 升级到 v7，runner 固定为 `ubuntu-24.04`
- LICENSE 版权方改为 StanleyChanH

## [0.1.0] - 2026-11-05

### Added

- Docker Compose 部署 DeepSeek Harness Web UI（`@deepseek-ai/dsh` 0.2.1-rc.5，Node 24）
- Nginx 反向代理：dsh 仅监听共享网络命名空间内的 `127.0.0.1`，支持 WebSocket 与长连接
- HTTP / HTTPS 两种模式，HTTPS 下 301 跳转、HSTS、会话 cookie 补 `Secure`
- 访问日志中的启动 token 自动打码；可选 Nginx Basic Auth
- 所有数据与配置以 bind mount 挂载在项目目录下
- `scripts/init.sh`、`scripts/show-url.sh`、`Makefile`
- 国内镜像源默认配置，可通过 `.env` 切换为官方源
- GitHub Actions CI：lint、两种模式的 Nginx 配置校验、构建并冒烟测试
