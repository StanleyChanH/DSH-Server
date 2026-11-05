# Changelog

本项目的所有重要变更记录在此文件中。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Fixed

- CI 中 hadolint DL3006 误报：`FROM` 显式写出 `node:<tag>`（`NODE_IMAGE` 构建参数更名为 `NODE_VERSION`）

### Changed

- CI 改为直接执行 `make lint`，lint 工具镜像版本在 Makefile 中固定，本地与 CI 结果一致
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
