# COMSOL MCP 使用指南

## 使用原则

MCP 客户端负责把自然语言转换成工具调用，MCP 服务再调用本机 COMSOL。LLM 不会
自己执行 COMSOL，也不能替代许可证、物理建模检查或结果复核。

- 同一时间只保留一个 MCP/COMSOL 会话，避免额外占用许可证和模型状态冲突；
- 输出一律使用服务器上的绝对路径；
- 每次运行创建新的输出目录，禁止默认覆盖已有 `.mph`；
- 建模前确认几何单位、材料、物理场、边界条件、网格、study 和求解目标；
- 高成本求解前要求客户端先总结即将执行的步骤并等待确认。

## 第一次最小闭环

先在 PowerShell 创建唯一输出目录：

```powershell
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$smokeDir = "T:\comsol_mcp\test_outputs\smoke_$stamp"
New-Item -ItemType Directory -Path $smokeDir -ErrorAction Stop
$smokeDir
```

然后在已连接 MCP 的 Codex、Cline、Cherry Studio 或 LibreChat 中依次发送：

```text
列出当前可用的 COMSOL MCP 工具，只读取状态，不启动 COMSOL。
```

```text
调用 comsol_status。如果尚未连接，调用 comsol_start，只使用 1 个 CPU 核心。
报告 COMSOL 版本和可用模块，不创建模型。
```

```text
创建一个空模型，将参数 mcp_smoke_length 设置为 1[um]，再读取并核对该参数。
不要求解，不要覆盖任何文件。
```

```text
将模型保存为 T:\comsol_mcp\test_outputs\smoke_YYYYMMDD_HHMMSS\mcp_smoke.mph。
保存前确认目标不存在；保存后重新载入并检查参数 mcp_smoke_length，最后断开 COMSOL。
```

把最后一条中的目录替换成刚创建的实际目录。只有工具可见、COMSOL 能启动、参数能
回读、模型能保存和重新载入，才算完整部署通过。

## SPP 建模工作流

仓库提供了 [`SPP_SIMULATION_PROMPT.md`](SPP_SIMULATION_PROMPT.md)。推荐将它作为
任务模板，并按以下阶段执行：

1. 只做需求澄清和模型计划，不调用写入型工具；
2. 核对维度、波长、材料色散、端口/周期边界/PML 和参数扫描范围；
3. 创建模型并保存一个未求解基线版本；
4. 汇报自由度、网格策略和预计成本，确认后再求解；
5. 导出结果时同时保存 `.mph`、参数表、图像和简短运行记录；
6. 对能量守恒、网格收敛和异常共振进行独立复核。

示例任务开头：

```text
请按 docs/SPP_SIMULATION_PROMPT.md 规划本次 SPP 仿真。当前只完成阶段 1：
列出缺失输入、物理假设、COMSOL 模块需求和计划使用的 MCP 工具，不修改模型。
所有后续文件写入 T:\comsol_mcp\runs\spp_20260818_001，禁止覆盖已有文件。
```

## 结束与故障恢复

任务结束时要求调用 `comsol_disconnect`。客户端异常退出后，先在任务管理器确认是否
遗留 COMSOL/Java/Python 子进程；若其仍在计算或模型未保存，不要直接结束进程。
确认无需保留后，再从客户端重新建立单一会话。
