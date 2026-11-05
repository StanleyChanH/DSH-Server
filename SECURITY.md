# 安全策略 / Security Policy

## 报告漏洞

**请不要在公开 Issue 中披露安全问题。** 请使用本仓库的 GitHub [Private vulnerability reporting](../../security/advisories/new)（Security → Report a vulnerability）提交。

请说明：受影响的文件/配置、复现步骤、影响范围。

## 范围

| 问题位置 | 报告去向 |
|---|---|
| 本仓库的部署配置：Nginx 配置、Compose 编排、镜像构建、脚本 | 本仓库 |
| DeepSeek Harness（`dsh`）本身：认证、沙箱、Agent 行为等 | 上游 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) |

## 部署安全须知

- dsh 是**单一 owner** 模型：登录链接（含启动 token）等同于完全控制权，只能发给可信用户。
- 公网部署请使用 `NGINX_MODE=https`，HTTP 模式下 token 与会话 cookie 为明文传输。
- 必要时启用 Nginx Basic Auth，或在安全组中限制来源 IP。
- 不要把 Docker socket、宿主机根目录或含凭据的目录挂载进 dsh 容器。
- `.env`、`data/`、`nginx/certs/` 含敏感信息，已被 `.gitignore` 排除，切勿提交。

---

## Reporting a vulnerability

**Do not disclose security issues in public issues.** Use GitHub's [private vulnerability reporting](../../security/advisories/new) for this repository. Issues in dsh itself belong upstream at [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness).
