# 参与贡献

感谢你的贡献！本仓库只包含部署配置（Compose、Nginx、Dockerfile、脚本），dsh 本身的问题请提交到[上游](https://github.com/deepseek-ai/deepseek-harness)。

## 开发流程

1. Fork 并创建分支：`git checkout -b feat/xxx`
2. 修改后在本地验证：
   ```sh
   make lint                   # shellcheck + hadolint + compose 配置校验
   ./scripts/init.sh 127.0.0.1 && docker compose up -d --build
   make url                    # 用浏览器走一遍登录流程
   ```
3. 若改动影响使用方式，同步更新 `README.md`、`README.en.md` 与 `.env.example`
4. 在 `CHANGELOG.md` 的 `Unreleased` 下记录变更
5. 提交 PR，CI 通过后合并

## 约定

- 提交信息使用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/)：`feat:`、`fix:`、`docs:`、`ci:`、`chore:` …
- Shell 脚本需通过 `shellcheck`，并使用 `set -euo pipefail`
- 新增配置项必须提供合理默认值，并写入 `.env.example` 与 README 的配置表
- 不要提交 `.env`、证书、`data/`、`workspace/` 中的内容
- 文件使用 LF 换行、UTF-8 编码（见 `.editorconfig`）
