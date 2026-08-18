# 网页对话操控 COMSOL MCP

## 结论

可以通过网页对话操控，但网页必须连接到一个支持 MCP 的后端。`chat.deepseek.com`
等纯厂商网页不能读取服务器上的本地 STDIO MCP；ChatGPT 网页也不会自动读取服务器
用户的 Codex MCP 配置。

本仓库推荐在安装 COMSOL 的同一台 Windows 服务器上原生运行 LibreChat：

```text
浏览器 → LibreChat Web/后端 → DeepSeek 或 OpenAI API
                         └→ STDIO MCP → Python/MPh → 本机 COMSOL
```

不推荐把 LibreChat 放进 Linux Docker 后再直接配置 Windows STDIO：容器内进程无法
直接启动宿主机的 Windows Python/COMSOL。若未来改成远程 Streamable HTTP MCP，
必须另行实现认证、TLS、授权和会话隔离；本仓库当前不提供这个高风险桥接层。

## 1. 安装前置软件

LibreChat 原生 npm 部署当前要求 Node.js 24.16.0、npm 11.16.0、Git 和 MongoDB。
先验证：

```powershell
node --version
npm --version
git --version
mongosh --eval "db.runCommand({ ping: 1 })"
```

具体版本和数据库步骤以
[LibreChat npm 安装文档](https://www.librechat.ai/docs/local/npm)为准。

## 2. 部署 LibreChat

建议放在本仓库之外，防止升级或提交时带入账号数据库和 Key：

```powershell
Set-Location T:\
git clone https://github.com/danny-avila/LibreChat.git T:\LibreChat
Set-Location T:\LibreChat
Copy-Item .env.example .env
Copy-Item T:\comsol_mcp\config\librechat.example.yaml .\librechat.yaml
notepad .env
```

在私有 `.env` 中至少配置 MongoDB 连接和模型 Key：

```dotenv
MONGO_URI=mongodb://127.0.0.1:27017/LibreChat
DEEPSEEK_API_KEY=在服务器本地填写真实值
```

不要把 `.env` 复制回本仓库。若使用 OpenAI，可按 LibreChat 官方环境变量说明加入
`OPENAI_API_KEY`，并在 `librechat.yaml` 中启用对应 endpoint；MCP 部分无需改变。

安装并启动：

```powershell
Set-Location T:\LibreChat
npm run reinstall
npm run backend
```

浏览器先只访问服务器本机的 `http://localhost:3080`。注册首个管理员账号后：

1. 在模型菜单选择 DeepSeek 和 `deepseek-v4-pro`；
2. 在 MCP 菜单启用 `comsol`；
3. 先发送“只调用 `comsol_status`，不要启动或修改模型”；
4. 再按 [`USAGE_GUIDE.md`](USAGE_GUIDE.md) 完成最小闭环。

模板 [`librechat.example.yaml`](../config/librechat.example.yaml) 已把 MCP 工具超时设为
10 分钟、启动超时设为 60 秒，并保留 DeepSeek 推理历史所需字段。配置字段以
[LibreChat MCP](https://www.librechat.ai/docs/features/mcp) 和
[mcpServers schema](https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/mcp_servers)
为准。

## 3. 局域网或公网访问

初次验收只使用 `localhost`。需要从其他电脑访问时，至少完成：

- LibreChat 账号注册策略和强密码；
- HTTPS 反向代理与可信证书；
- Windows 防火墙仅放行预期来源；
- 不直接暴露 MongoDB、MCP STDIO 或 COMSOL 端口；
- API Key 只保留在服务器端 Secret/`.env`；
- 记录登录、工具调用和模型文件输出，但日志不得包含 Key；
- 定期更新 LibreChat，并在更新后重新做最小闭环。

不要把 `0.0.0.0:3080` 直接暴露到公网。反向代理和身份认证尚未完成时，应通过
远程桌面、VPN 或 SSH 隧道访问 `localhost`。

## 4. 多用户和许可证限制

每个 Web 会话都可能启动独立 MCP/COMSOL 子进程，导致许可证耗尽、同一模型被并发
修改或服务器资源争用。初期按单用户、单会话、一次一个求解任务运行。若要多人使用，
需增加任务队列、每用户输出目录、并发上限、许可证配额和管理员审计后再开放。
