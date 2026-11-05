# 可选：Nginx Basic Auth（在 dsh 自身 token 认证之外再加一层）

只有本目录下的 `*.conf` 会被加载。启用步骤：

```sh
# 1. 生成账号密码文件（在项目根目录执行）
docker run --rm --entrypoint htpasswd httpd:2.4-alpine -nbB <用户名> <密码> >> nginx/snippets/auth/htpasswd

# 2. 启用配置
cp nginx/snippets/auth/basic-auth.conf.example nginx/snippets/auth/basic-auth.conf

# 3. 重载 nginx
docker compose exec nginx nginx -s reload
```
