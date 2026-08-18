# COMSOL MCP 部署仓库

本仓库用于把非官方
[`wjc9011/COMSOL_Multiphysics_MCP`](https://github.com/wjc9011/COMSOL_Multiphysics_MCP)
通过 GitHub 同步到安装了 COMSOL 的 Windows 服务器。上游源码以 Git submodule 固定到
[UPSTREAM_COMMIT](UPSTREAM_COMMIT) 中的提交。

当前电脑没有 COMSOL，仅维护部署配置和文档；不在这里制作迁移包、虚拟环境或离线依赖。

## 快速部署

目标服务器已知环境：Windows AMD64、Python 3.13.5、已安装 COMSOL。

首次同步：

```powershell
git clone --recurse-submodules https://github.com/dzx0902/Comsol-MCP-Agent.git T:\comsol_mcp
cd T:\comsol_mcp
.\scripts\Setup-OnServer.ps1 -PythonExe python -ExpectedPythonVersion 3.13.5
```

以后同步更新：

```powershell
cd T:\comsol_mcp
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive
```

## 文档导航

- [服务器完整落地命令](docs/SERVER_DEPLOYMENT.md)
- [COMSOL MCP 操作与最小验收](docs/USAGE_GUIDE.md)
- [Codex、DeepSeek、Cline、Cherry Studio 配置](docs/LLM_CLIENT_CONFIG.md)
- [LibreChat 网页对话接入](docs/WEB_CHAT_GUIDE.md)
- [部署边界与版本计划](DEPLOYMENT_PLAN.md)
- [SPP 建模提示模板](docs/SPP_SIMULATION_PROMPT.md)

配置模板位于 `config/`。所有示例均不包含真实 API Key；`.venv`、`.mph`、日志、
许可证和私有 `.env` 不进入 Git。
