# COMSOL MCP 部署仓库

本仓库用于把非官方
[`wjc9011/COMSOL_Multiphysics_MCP`](https://github.com/wjc9011/COMSOL_Multiphysics_MCP)
通过 GitHub 同步到安装了 COMSOL 的 Windows 服务器。上游源码以 Git submodule 固定到
[UPSTREAM_COMMIT](UPSTREAM_COMMIT) 中的提交。

当前电脑没有 COMSOL，仅维护部署配置和文档；不在这里制作迁移包、虚拟环境或离线依赖。

## 服务器部署

目标服务器已知环境：Windows AMD64、Python 3.13.5、已安装 COMSOL。

首次同步：

```powershell
git clone --recurse-submodules <你的GitHub仓库URL> T:\comsol_mcp
cd T:\comsol_mcp
.\scripts\Test-Environment.ps1 -Role Server -PythonExe python

cd .\vendor\COMSOL_Multiphysics_MCP
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U pip
.\.venv\Scripts\python.exe -m pip install -e .
```

以后同步更新：

```powershell
cd T:\comsol_mcp
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive
```

完整验证步骤见 [DEPLOYMENT_PLAN.md](DEPLOYMENT_PLAN.md)，Codex 配置见
[config/codex.comsol.example.toml](config/codex.comsol.example.toml)，SPP 建模提示模板见
[docs/SPP_SIMULATION_PROMPT.md](docs/SPP_SIMULATION_PROMPT.md)。

