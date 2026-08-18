# COMSOL MCP GitHub 部署计划

## 1. 部署边界

- MCP 项目是非官方 `wjc9011/COMSOL_Multiphysics_MCP`。
- 当前电脑只维护 Git 仓库，不安装或验证 COMSOL。
- 目标服务器：Windows AMD64、Python 3.13.5、已安装 COMSOL。
- 首阶段仅使用本地 STDIO MCP，不配置远程 HTTP MCP。
- 不提交 `.venv`、`.mph` 模型、许可证、API key、日志或个人 Codex 配置。

## 2. 仓库结构

```text
comsol_mcp/                              # 本部署仓库
├── vendor/COMSOL_Multiphysics_MCP/      # 固定 commit 的 Git submodule
├── config/codex.comsol.example.toml
├── scripts/Test-Environment.ps1
└── docs/SPP_SIMULATION_PROMPT.md
```

上游版本由 Git submodule 和 `UPSTREAM_COMMIT` 双重记录。升级上游时应单独提交，并在服务器重新验证。

## 3. 发布到 GitHub

在本机为当前仓库配置你自己的 GitHub remote，然后推送：

```powershell
git remote add origin <你的GitHub仓库URL>
git push -u origin main
```

若已有 `origin`，先运行 `git remote -v` 核对，不要重复添加或覆盖。

## 4. 服务器首次部署

```powershell
git clone --recurse-submodules <你的GitHub仓库URL> T:\comsol_mcp
cd T:\comsol_mcp
.\scripts\Test-Environment.ps1 -Role Server -PythonExe python
```

环境检查必须确认：

- Python 返回 3.13.5、AMD64、64bit；
- Git 与 Codex 可用；
- 检测到实际 COMSOL 安装目录；
- `T:` 盘存在；
- 所需 Wave Optics Module 许可可用。

然后在服务器本地创建虚拟环境：

```powershell
cd T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U pip
.\.venv\Scripts\python.exe -m pip install -e .
.\.venv\Scripts\python.exe -m pip check
```

虚拟环境始终由服务器上的 Python 3.13.5 创建，不通过 Git 同步。

## 5. MCP 启动验证

```powershell
cd T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP
.\.venv\Scripts\python.exe -m src.server
```

STDIO 服务启动后等待输入、没有交互提示是正常现象，可用 `Ctrl+C` 停止。若失败，按错误区分依赖、COMSOL 发现、Java API、许可证或服务端代码问题。

## 6. Codex 配置

先备份服务器用户的配置：

```powershell
$config = Join-Path $env:USERPROFILE '.codex\config.toml'
if (Test-Path -LiteralPath $config) {
    Copy-Item -LiteralPath $config -Destination "$config.bak" -ErrorAction Stop
}
```

把 `config/codex.comsol.example.toml` 中的配置合并到原文件，不要整文件覆盖。验证：

```powershell
codex mcp list
codex mcp get comsol
```

随后在 Codex TUI 中运行 `/mcp`；VS Code Codex 扩展重启后应读取同一主机配置。

## 7. 最小功能闭环

在全新的 `T:\comsol_mcp\test_outputs\smoke_<timestamp>` 中执行，禁止覆盖已有 `.mph`：

1. 查看 MCP 工具；
2. 调用 `comsol_status`；
3. 调用 `comsol_start`；
4. `model_create` 创建空模型；
5. `param_set` 设置 `mcp_smoke_length = 1[um]`；
6. 回读参数；
7. 保存、重新加载并检查模型；
8. `comsol_disconnect`。

只有工具可见、COMSOL 启动成功、参数可回读且新模型能保存/加载，才算部署完成。

## 8. 日常更新

```powershell
cd T:\comsol_mcp
git pull --ff-only
git submodule sync --recursive
git submodule update --init --recursive
```

上游 submodule 更新后，服务器应再次运行 `pip install -e .`、`pip check` 和最小功能闭环。不要在服务器直接修改 submodule 后忘记提交到独立分支或 fork。

