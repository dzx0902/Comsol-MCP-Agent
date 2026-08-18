# Windows 服务器落地指南

本指南面向安装了 COMSOL 的目标服务器。已知目标环境为 Windows AMD64、
Python 3.13.5；本仓库通过 GitHub 同步，不传输虚拟环境或离线安装包。

## 1. 前置条件

- 64 位 Windows，已安装可正常启动的 COMSOL Multiphysics；
- COMSOL 及所需模块许可证可用；
- 64 位 CPython 3.13.5、Git；
- 若使用 Codex，再安装 Codex CLI；
- 能访问 GitHub 和 Python 包索引。

COMSOL 与 Python 必须位于同一台 Windows 主机。MPh 会通过 COMSOL 的 Java
接口启动本机 COMSOL，不能在一台没有 COMSOL 的电脑上完成最终联调。

## 2. 首次部署（推荐）

在普通 PowerShell 中执行；只有 COMSOL 或 Python 安装程序要求时才使用管理员权限。

```powershell
git clone --recurse-submodules https://github.com/dzx0902/Comsol-MCP-Agent.git T:\comsol_mcp
Set-Location T:\comsol_mcp
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Setup-OnServer.ps1 -PythonExe python -ExpectedPythonVersion 3.13.5
```

COMSOL 安装在非标准目录时，可显式传入根目录：

```powershell
.\scripts\Setup-OnServer.ps1 `
  -PythonExe python `
  -ExpectedPythonVersion 3.13.5 `
  -ComsolRoot 'T:\Comsol\COMSOL64\Multiphysics'
```

环境检查会依次使用显式路径、`HKLM\SOFTWARE\Comsol` 注册表、当前 PATH 和标准
安装目录，不要求 COMSOL 必须位于 `C:\Program Files`。

脚本会严格检查 Python 3.13.5、AMD64/64bit，拉取固定版本的 submodule，
在上游目录内创建 `.venv`，安装依赖并执行导入检查。它不会启动 COMSOL，也不会
消耗许可证会话。

若 `python` 不是目标解释器，传入完整路径：

```powershell
.\scripts\Setup-OnServer.ps1 `
  -PythonExe 'C:\Program Files\Python313\python.exe' `
  -ExpectedPythonVersion 3.13.5
```

## 3. 完整手工命令

自动脚本失败时，可逐步执行以下等价命令来定位问题：

```powershell
Set-Location T:\comsol_mcp
python -c "import platform,sys; print(sys.version); print(platform.machine(), platform.architecture()[0])"
git submodule sync --recursive
git submodule update --init --recursive

Set-Location T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -e .
.\.venv\Scripts\python.exe -m pip check
.\.venv\Scripts\python.exe -c "import mph,mcp,src.server; print('imports OK')"
```

确认同步的是仓库固定的上游提交：

```powershell
Set-Location T:\comsol_mcp
git status --short
git submodule status --recursive
Get-Content .\UPSTREAM_COMMIT
git -C .\vendor\COMSOL_Multiphysics_MCP rev-parse HEAD
```

最后两条输出的提交号应一致，`git status --short` 应无输出。

## 4. COMSOL 与许可证验证

以下命令会真正启动 COMSOL，可能占用一个许可证会话。先关闭不需要的 COMSOL
桌面实例，再执行：

```powershell
$venvPython = 'T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP\.venv\Scripts\python.exe'
& $venvPython -c "from mph.discovery import find_backends; print(find_backends())"
& $venvPython -c "import mph; c=mph.start(cores=1); print(c); print(c.modules()); c.clear()"
```

第一条应发现本机 COMSOL 后端，第二条应能启动客户端并列出模块。若 COMSOL
安装在非标准位置，先依据 MPh 的报错和 COMSOL 实际安装目录排查；不要猜测并永久
修改系统环境变量。

## 5. 独立启动 MCP（诊断用）

```powershell
Set-Location T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP
.\.venv\Scripts\python.exe -m src.server
```

STDIO 服务会等待 MCP 客户端输入，没有网页、提示符或普通交互菜单是正常的。
按 `Ctrl+C` 停止。正常使用时由 Codex、Cline、Cherry Studio 或 LibreChat 自动启动，
不要同时手工再启动一份。

## 6. Codex 接入

先备份服务器当前用户的配置：

```powershell
$codexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'
if (Test-Path -LiteralPath $codexConfig) {
  Copy-Item -LiteralPath $codexConfig -Destination "$codexConfig.bak" -ErrorAction Stop
}
notepad $codexConfig
```

把仓库中的 [`config/codex.comsol.example.toml`](../config/codex.comsol.example.toml)
内容合并进现有文件，不能整文件覆盖。随后验证：

```powershell
codex mcp list
codex mcp get comsol
codex
```

进入 Codex 后执行 `/mcp`，应看到 `comsol` 及其工具。VS Code Codex 扩展和 CLI
读取同一个主机用户配置；修改后请重启客户端。

## 7. 更新与回滚

日常同步：

```powershell
Set-Location T:\comsol_mcp
git status --short
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive
& .\vendor\COMSOL_Multiphysics_MCP\.venv\Scripts\python.exe -m pip install -e .\vendor\COMSOL_Multiphysics_MCP
& .\vendor\COMSOL_Multiphysics_MCP\.venv\Scripts\python.exe -m pip check
```

`git status --short` 若有输出，先确认这些服务器本地修改是否需要保留，不要强制覆盖。
上游由 submodule 提交号锁定；仓库回退到上一个已验证提交后再运行 `git submodule
update --init --recursive`，即可同步回对应版本。

## 8. 常见错误

- `Expected Python 3.13.5`：当前 `python` 指向了其他解释器，传入正确的完整路径。
- `No COMSOL installation was found`：核对真实安装目录和版本；也可先运行 COMSOL
  桌面确认安装与许可证本身正常。
- `find_backends()` 为空：通常是 Python/COMSOL 位数不一致、非标准安装或注册信息缺失。
- Java、启动或许可证异常：先用同一 Windows 用户启动一次 COMSOL 桌面，再查看
  MPh 输出和 COMSOL License Manager 状态。
- MCP 启动超时：首次 COMSOL 启动可能较慢，可提高客户端启动超时，但不要无限延长。
- 工具能看到但求解失败：这是模型或物理设置问题，不代表 MCP 连接失败；先做最小闭环。

MPh 安装与发现行为以其官方文档为准：
[Installation](https://mph.readthedocs.io/en/stable/installation.html)、
[Discovery](https://mph.readthedocs.io/en/stable/api/mph.discovery.html)。
