# COMSOL MCP 部署编排仓库

本仓库依据 `prompt.md` 管理非官方
[`wjc9011/COMSOL_Multiphysics_MCP`](https://github.com/wjc9011/COMSOL_Multiphysics_MCP)
的可复现构建和 Windows 服务器部署。它不包含 COMSOL、许可证、私有模型、API key 或 Python 虚拟环境。

当前电脑是**构建机**，没有 COMSOL，也没有 `T:` 盘；因此这里能完成依赖打包、源码固定和静态检查，不能宣称 COMSOL 联调成功。MCP、COMSOL Java API、许可证与最小模型闭环必须在安装了 COMSOL 的目标 Windows 服务器上验收。

## 快速入口

1. 阅读 [DEPLOYMENT_PLAN.md](DEPLOYMENT_PLAN.md)。
2. 先确认目标服务器的 Windows 架构和 Python **主/次版本**。
3. 在构建机执行：

   ```powershell
   .\scripts\Test-Environment.ps1 -Role Build
   .\scripts\New-TransferBundle.ps1 -PythonExe "C:\Path\To\matching-python.exe"
   ```

4. 把 `artifacts\comsol-mcp-bundle-*.zip` 复制到服务器，校验 SHA-256，解压。
5. 在服务器的解压目录执行：

   ```powershell
   .\scripts\Test-Environment.ps1 -Role Server
   .\scripts\Install-OnComsolServer.ps1 -InstallRoot 'T:\COMSOL_Multiphysics_MCP'
   ```

6. 按安装脚本输出配置 Codex，再执行 `codex mcp list` 和 `/mcp`。

`New-TransferBundle.ps1` 固定使用 [UPSTREAM_COMMIT](UPSTREAM_COMMIT) 中的提交，并把解析后的 Windows wheels、源码快照、运行时信息和校验清单一起打包。不要跨 Python 主/次版本或跨 CPU 架构搬运虚拟环境。

研究建模的确认式提示模板见 [docs/SPP_SIMULATION_PROMPT.md](docs/SPP_SIMULATION_PROMPT.md)。

