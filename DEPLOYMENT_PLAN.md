# COMSOL MCP 构建与迁移部署计划

## 1. 范围与边界

- MCP 项目：非官方 `wjc9011/COMSOL_Multiphysics_MCP`。
- 传输：先做 Windows 本地 STDIO MCP；不部署网页端或远程 HTTP MCP。
- 构建机：准备源码快照和离线 wheelhouse，不需要 COMSOL。
- 目标服务器：必须有可用的 COMSOL 5.x/6.x、本地许可、Java API 及与构建包匹配的 Python 3.10+。
- 本仓库不修改全局 Python、系统环境变量或已有 Codex 配置，也不删除/重装 COMSOL。
- 虚拟环境不可搬运。服务器必须从迁移包重新创建 `.venv`。

上游当前固定到 `UPSTREAM_COMMIT`。升级上游必须单独提交，并重新构建、复测迁移包。

## 2. 关键架构决定

```text
构建机（无 COMSOL）
  固定上游 commit -> 构建项目 wheel + 下载依赖 wheels -> SHA-256 清单 -> ZIP
                                                                  |
                                                           受控文件传输
                                                                  v
COMSOL Windows 服务器
  校验哈希 -> 检测 COMSOL/Python -> 新建 .venv -> 离线安装 -> STDIO MCP -> Codex
                                                                  |
                                                                  v
                                     创建空模型 -> 参数 -> 保存到 test_outputs
```

MCP 进程和 COMSOL 应部署在同一台 Windows 服务器。Codex CLI/IDE 也在该服务器会话中运行并通过 STDIO 启动 MCP。若 Codex 在另一台电脑，STDIO 配置不会自动跨主机工作，那属于后续远程执行器或 HTTP MCP 阶段。

## 3. 阶段与验收门

### A. 服务器信息确认（构建前）

收集并记录：

- Windows 版本与 `AMD64/ARM64` 架构；
- `python --version` 和 `python -c "import platform; print(platform.machine())"`；
- COMSOL 版本、安装根目录、所需 Wave Optics Module 是否已许可；
- Codex CLI 版本及其运行账户；
- 服务器实际工作盘（若无 `T:`，修改安装根目录）。

验收门 A：构建 Python 与服务器 Python 的主/次版本、架构一致。构建机当前 Python 是 3.12.4/Windows，目标信息尚未确认。

### B. 构建机生成迁移包

```powershell
.\scripts\Test-Environment.ps1 -Role Build
.\scripts\New-TransferBundle.ps1 -PythonExe 'C:\Path\To\matching-python.exe'
```

脚本会：

1. 克隆并 checkout 固定 commit；
2. 用独立构建虚拟环境运行 `pip wheel`；
3. 生成上游源码快照、wheelhouse、Python 运行时元数据和 `SHA256SUMS.txt`；
4. 输出 ZIP 及 ZIP 的 `.sha256` 文件。

验收门 B：脚本退出码为 0；ZIP 和 `.sha256` 同时存在；包内至少有 `comsol_mcp-*.whl`。

### C. 服务器离线安装

先校验传输文件：

```powershell
Get-FileHash .\comsol-mcp-bundle-*.zip -Algorithm SHA256
Get-Content .\comsol-mcp-bundle-*.zip.sha256
```

解压后执行：

```powershell
.\scripts\Test-Environment.ps1 -Role Server
.\scripts\Install-OnComsolServer.ps1 -InstallRoot 'T:\COMSOL_Multiphysics_MCP'
```

安装脚本只接受一个尚不存在的安装目录，创建服务器本地 `.venv`，从 wheelhouse 离线安装，并做不启动 COMSOL 的 Python import 检查。若安装目录已存在，先人工检查和备份，不自动覆盖。

验收门 C：环境检查发现 COMSOL；Python 版本/架构匹配；`import src.server` 成功。

### D. COMSOL 与 MCP 联调

在服务器安装目录中运行：

```powershell
.\.venv\Scripts\python.exe -m src.server
```

STDIO 服务正常等待输入可能表现为“没有提示且不退出”，这是正常现象；用 `Ctrl+C` 停止。日志必须写 stderr，不能向 stdout 输出非 MCP 协议文本。

通过 MCP 客户端依次调用：

1. `comsol_status`；
2. `comsol_start`（可显式给出检测到的版本）；
3. 再次 `comsol_status`。

故障分类：

| 症状 | 最小诊断 | 处理方向 |
|---|---|---|
| import/module error | `.venv\Scripts\python -m pip check` | 重新核对 wheelhouse 与 Python ABI，不升级全局环境 |
| 找不到 COMSOL | `Test-Environment.ps1 -Role Server` | 核实安装根目录与 MPh 发现机制，不猜路径 |
| JVM/Java class error | 检查 COMSOL 自带 Java、`mph` 诊断输出 | 保持 COMSOL 自带 Java；核对版本兼容性 |
| license checkout failed | 用同一账户启动 COMSOL 或 `mphserver` | 交由许可证管理员确认产品与并发许可 |
| MCP 初始化失败 | 手动启动、查看 stderr，运行 `codex mcp get comsol` | 区分 TOML、cwd、Python 与服务端异常 |

验收门 D：`comsol_start` 返回成功和版本信息。

### E. Codex 配置

官方 Codex 支持用户级 `~/.codex/config.toml` 和可信项目内 `.codex/config.toml`，CLI 与 IDE 扩展共享同一主机的 MCP 配置。先备份用户配置：

```powershell
$config = Join-Path $env:USERPROFILE '.codex\config.toml'
if (Test-Path -LiteralPath $config) { Copy-Item -LiteralPath $config -Destination "$config.bak" -ErrorAction Stop }
```

把 [config/codex.comsol.example.toml](config/codex.comsol.example.toml) 中路径改为服务器实际绝对路径后，**合并**到已有配置，不要整文件覆盖。然后：

```powershell
codex mcp list
codex mcp get comsol
```

在 Codex TUI 中运行 `/mcp`。重启 IDE 扩展后再检查其 MCP 列表。

验收门 E：`comsol` 已启用，命令、cwd 和超时正确，初始化无错误。

### F. 最小功能闭环

测试目录仅使用新路径 `T:\COMSOL_Multiphysics_MCP\test_outputs\smoke_<timestamp>`，不得覆盖已有 `.mph`：

1. 列出 MCP 工具；
2. `comsol_start`；
3. `model_create` 创建空模型；
4. `param_set` 设置 `mcp_smoke_length = 1[um]`；
5. `param_get` 或 `param_list` 回读；
6. `model_save` 到新建 smoke 目录；
7. `model_inspect` 回读结构；
8. `comsol_disconnect`。

验收门 F：工具可见、参数回读一致、产生一个新的 `.mph` 文件且能再次加载。保存前应让用户确认最终绝对路径。

## 4. 完成定义

只有 A-F 全部通过，才报告“部署成功”。本机当前只能完成方案、上游固定、环境静态检查和迁移包构建；没有 COMSOL 的情况下，D-F 不能验证。

最终交付记录应包含：迁移包哈希、上游 commit、Python/COMSOL/Codex 版本、安装路径、配置变更及备份路径、每个验收门证据、最小测试模型路径，以及失败时唯一的下一步诊断命令。

