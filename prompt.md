你现在是我的本地工程助手，任务是帮我在 Windows 环境下配置 COMSOL MCP，并让本地 Codex 可以通过 MCP 调用 COMSOL。

我的目标：

1. 部署非官方 COMSOL MCP Server；
2. 优先使用 wjc9011/COMSOL_Multiphysics_MCP 项目；
3. 让 Codex CLI / VS Code Codex 扩展可以通过 MCP 调用它；
4. 最后跑通一个最小测试闭环：启动 MCP → Codex 识别 MCP server → 调用 COMSOL MCP 工具 → 创建/读取模型 → 设置参数或执行简单操作；
5. 暂时不要处理网页端 AI，也不要先做远程 HTTP MCP，先完成本地 STDIO MCP。

我的环境背景：

- 系统：Windows 11
- 主要工作盘：T:\
- 我希望把项目放在：T:\COMSOL_Multiphysics_MCP
- 我有本地 Codex CLI / VS Code Codex 扩展
- 我希望之后可以把同一个 MCP server 给 Cherry Studio / Cline / DeepSeek 等客户端复用
- COMSOL 本体需要本地已有安装和许可；如果你无法确认路径，请先帮我写检测命令，不要猜路径

请按以下步骤执行：

第一步：检查环境

- 检查 Python 版本，要求 Python 3.10+
- 检查 git 是否可用
- 检查 codex 是否可用
- 检查 COMSOL 是否可能已安装，包括常见路径：
  - C:\Program Files\COMSOL
  - C:\Program Files\COMSOL\COMSOL60
  - C:\Program Files\COMSOL\COMSOL61
  - C:\Program Files\COMSOL\COMSOL62
  - C:\Program Files\COMSOL\COMSOL63
- 不要修改系统环境变量，除非我确认

第二步：克隆并安装 COMSOL MCP

- 如果 T:\COMSOL_Multiphysics_MCP 不存在，则 clone：
  <https://github.com/wjc9011/COMSOL_Multiphysics_MCP.git>
- 如果已经存在，则进入该目录，检查 git status
- 创建 Python 虚拟环境：
  python -m venv .venv
- 激活虚拟环境：
  .\.venv\Scripts\Activate.ps1
- 安装项目依赖：
  python -m pip install -U pip
  python -m pip install -e .
- 如果安装失败，请完整分析错误原因，并给出最小修改建议；不要盲目升级/删除大量依赖

第三步：测试 MCP server 是否能启动

- 在项目目录运行：
  python -m src.server
- 如果启动失败，请判断是：
  1. Python 依赖问题；
  2. COMSOL 路径问题；
  3. Java / COMSOL API 问题；
  4. MCP server 代码问题；
  5. 权限或许可证问题。
- 每类问题都要给出明确诊断命令和修复建议

第四步：配置 Codex MCP

- 找到或创建 Codex 配置文件：
  %USERPROFILE%\.codex\config.toml
- 在不破坏我已有配置的前提下，添加 COMSOL MCP server 配置
- 推荐配置如下，但请根据实际路径修正：

[mcp_servers.comsol]
command = "T:\\COMSOL_Multiphysics_MCP\\.venv\\Scripts\\python.exe"
args = ["-m", "src.server"]
cwd = "T:\\COMSOL_Multiphysics_MCP"
startup_timeout_sec = 60
tool_timeout_sec = 600
enabled = true
default_tools_approval_mode = "prompt"

- 如果我的 Codex 版本使用的是不同字段名，请根据本地 codex 文档或报错调整
- 配置前请备份原始 config.toml 为 config.toml.bak

第五步：验证 Codex 是否识别 MCP

- 运行：
  codex mcp list
- 启动 codex 后检查：
  /mcp
- 如果 comsol 没有出现，请检查：
  1. config.toml 路径是否正确；
  2. TOML 格式是否正确；
  3. command 路径是否正确；
  4. MCP server 是否可以通过 STDIO 启动；
  5. Codex 版本是否支持 MCP；
  6. Windows 路径转义是否正确

第六步：做一个最小功能测试

- 不要一上来做复杂 SPP 仿真
- 先让 MCP server 完成最简单的操作，例如：
  1. 查看可用工具；
  2. 创建空 COMSOL model；
  3. 设置一个简单参数；
  4. 保存模型到 T:\COMSOL_Multiphysics_MCP\test_outputs；
  5. 如果支持，导出一个简单结果或日志
- 所有操作都要尽量保守，避免覆盖已有 .mph 文件

第七步：输出最终结果
请给我输出：

1. 当前安装是否成功；
2. Codex 是否成功识别 comsol MCP；
3. 成功/失败的关键证据；
4. 已修改的文件列表；
5. 当前可用的启动命令；
6. 后续我可以如何在 Codex 里调用 COMSOL MCP；
7. 如果失败，请给出下一步最小排错路径，不要泛泛而谈。

重要要求：

- 不要把 COMSOL MCP 当成官方 COMSOL 产品；
- 不要假设我有 COMSOL Server 许可，先检测；
- 不要删除或重装我的 COMSOL；
- 不要修改全局 Python 环境；
- 不要把 API key 或个人信息写入仓库；
- 所有修改前先说明目的；
- 如果需要改配置文件，先备份；
- 如果遇到路径、版本、许可不确定，优先用命令检测，不要直接猜。

完成部署后，请再给我一个用于实际仿真的 Codex 使用模板，面向我的研究方向：

- plasmonic / SPP
- thin gold film
- eigenmode search
- mica substrate n=1.55
- gold optical constants from Yakubovsky 2019
- 目标是让 AI 辅助 COMSOL 建模、参数扫描和结果提取，但关键物理假设必须先让我确认。
