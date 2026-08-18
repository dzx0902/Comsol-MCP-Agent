# LLM 与 MCP 客户端配置

## 先理解两层配置

LLM API 和 MCP 是两个独立层次：

| 层次 | 作用 | 示例 |
|---|---|---|
| LLM/模型提供方 | 理解对话并决定调用哪些工具 | OpenAI、DeepSeek |
| MCP 主机客户端 | 启动 `src.server`、执行工具并把结果回传给模型 | Codex、Cline、Cherry Studio、LibreChat |

只配置 DeepSeek API 不会自动获得 COMSOL 工具；客户端还必须加载 `comsol` MCP。
模型必须支持 tool/function calling。API Key 只放在服务器用户环境或客户端的私有
Secret/.env 中，绝不能写入 Git、聊天内容、截图或 `.mph` 元数据。

## 方案 A：Codex + OpenAI

Codex 完成正常登录后，只需把
[`codex.comsol.example.toml`](../config/codex.comsol.example.toml) 合并到
`%USERPROFILE%\.codex\config.toml`。验证：

```powershell
codex mcp list
codex mcp get comsol
codex
```

Codex CLI 和 VS Code Codex 扩展共享该主机用户的配置。MCP 配置的官方说明见
[Codex MCP 文档](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)。

## 方案 B：Codex + DeepSeek API

DeepSeek 当前官方 Codex 集成使用 Responses API，模型选择 `deepseek-v4-pro` 或
`deepseek-v4-flash`。先在 DeepSeek 控制台创建 API Key，并仅在当前 PowerShell
进程中设置：

```powershell
$secureKey = Read-Host 'DeepSeek API Key' -AsSecureString
$keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try {
  $env:DEEPSEEK_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
}
```

官方提供了 Codex 配置脚本。为了能先审查内容，下载后再运行，不使用管道直接执行：

```powershell
$setupScript = Join-Path $env:TEMP 'codex-deepseek-setup-en.ps1'
Invoke-WebRequest `
  -Uri 'https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.ps1' `
  -OutFile $setupScript
Get-Content -LiteralPath $setupScript
& $setupScript
```

脚本会备份 Codex 配置、写入 DeepSeek 模型提供方和模型目录，并保留已有 MCP 设置。
运行后重新打开终端，启动 Codex 并选择 DeepSeek 模型，再执行 `/mcp` 验证 `comsol`。
若脚本提示 Key，将 Key 直接输入终端，不要保存进本仓库。官方步骤见
[DeepSeek × Codex](https://api-docs.deepseek.com/quick_start/agent_integrations/codex/)。

可先独立测试 API（不会调用 MCP）：

```powershell
$headers = @{
  Authorization = "Bearer $env:DEEPSEEK_API_KEY"
  'Content-Type' = 'application/json'
}
$body = @{
  model = 'deepseek-v4-flash'
  messages = @(@{ role = 'user'; content = 'Reply with API_OK only.' })
  stream = $false
} | ConvertTo-Json -Depth 6
Invoke-RestMethod -Method Post -Uri 'https://api.deepseek.com/chat/completions' `
  -Headers $headers -Body $body
```

模型只提出工具调用，实际执行仍由 Codex/MCP 主机完成，参见
[DeepSeek Tool Calls](https://api-docs.deepseek.com/guides/tool_calls)。

## 方案 C：Cline + 任意模型提供方

Cline 可在 VS Code 中选择 OpenAI、DeepSeek或 OpenAI-compatible 提供方。模型端填写
客户端所要求的 API Key、Base URL 和 tool-capable 模型；DeepSeek Base URL 为
`https://api.deepseek.com`，优先使用 `deepseek-v4-pro`。

MCP 配置：

1. 打开 Cline 的 MCP Servers，选择 Configure；
2. 将 [`cline.mcp.example.json`](../config/cline.mcp.example.json) 中 `comsol` 节点
   合并到 Cline 打开的 MCP 配置；Cline CLI 通常使用 `%USERPROFILE%\.cline\mcp.json`；
3. 保持 `autoApprove` 为空，重启 Cline；
4. 确认 `comsol` 为启用状态，并先做只读的 `comsol_status`。

如果服务器路径不是 `T:\comsol_mcp`，同时修改 `command`。Cline 的 MCP 配置格式见
[官方 MCP Overview](https://github.com/cline/cline/blob/main/docs/mcp/mcp-overview.mdx)。

## 方案 D：Cherry Studio + DeepSeek/OpenAI

Cherry Studio 是桌面客户端，必须安装在 COMSOL 所在的 Windows 服务器上，或通过
远程桌面使用服务器上的 Cherry Studio。配置步骤：

1. 在“设置 → 模型服务”启用 DeepSeek 或 OpenAI，填入私有 Key；
2. DeepSeek 使用 `https://api.deepseek.com` 和 `deepseek-v4-pro`；
3. 在“设置 → MCP”新增 STDIO 服务 `comsol`；
4. Command 填
   `T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP\.venv\Scripts\python.exe`；
5. Arguments 分别填写 `-m`、`src.server`；若有 Working directory，填写
   `T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP`；
6. 不启用危险工具自动批准，保存并检查工具列表。

DeepSeek 的 Cherry Studio 指南见
[官方集成说明](https://github.com/deepseek-ai/awesome-deepseek-agent/blob/main/docs/cherry_studio.md)。

## 方案 E：其他 OpenAI-compatible 客户端

只有同时满足以下条件才能使用：客户端支持本地 STDIO MCP、支持工具调用，并允许
配置所选模型的兼容 API。通用 MCP 启动参数是：

```text
command: T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP\.venv\Scripts\python.exe
args:    -m, src.server
cwd:     T:\comsol_mcp\vendor\COMSOL_Multiphysics_MCP（客户端支持时填写）
```

不同客户端对 DeepSeek 推理字段的保留方式不同。若工具调用出现循环、空响应或推理
历史丢失，应使用客户端明确支持的 DeepSeek 集成，而不是随意映射字段。
