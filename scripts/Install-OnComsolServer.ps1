[CmdletBinding()]
param(
    [string]$InstallRoot = 'T:\COMSOL_Multiphysics_MCP',
    [string]$PythonExe = 'python'
)

$ErrorActionPreference = 'Stop'
$bundleRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $bundleRoot 'SHA256SUMS.txt'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Bundle SHA256SUMS.txt is missing.' }
$bundlePrefix = $bundleRoot.TrimEnd('\') + '\'
foreach ($line in Get-Content -LiteralPath $manifestPath) {
    if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') { throw "Invalid checksum line: $line" }
    $expectedHash = $Matches[1].ToLowerInvariant()
    $relativePath = $Matches[2].Replace('/', '\')
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $bundleRoot $relativePath))
    if (-not $candidate.StartsWith($bundlePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Checksum path escapes the bundle: $relativePath"
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Bundle file is missing: $relativePath" }
    $actualHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) { throw "Checksum mismatch: $relativePath" }
}
$appSource = Join-Path $bundleRoot 'app'
$wheelhouse = Join-Path $bundleRoot 'wheelhouse'
$runtimeFile = Join-Path $bundleRoot 'python-runtime.json'
if (-not (Test-Path -LiteralPath $appSource -PathType Container)) { throw 'Bundle app directory is missing.' }
if (-not (Test-Path -LiteralPath $wheelhouse -PathType Container)) { throw 'Bundle wheelhouse is missing.' }
if (-not (Test-Path -LiteralPath $runtimeFile -PathType Leaf)) { throw 'Bundle runtime metadata is missing.' }

$installFull = [System.IO.Path]::GetFullPath($InstallRoot)
if (Test-Path -LiteralPath $installFull) {
    throw "InstallRoot already exists: $installFull. Inspect and back it up manually; this script will not overwrite it."
}

$built = Get-Content -Raw -LiteralPath $runtimeFile | ConvertFrom-Json
$serverJson = & $PythonExe -c 'import json,platform,sys; print(json.dumps({"version": list(sys.version_info[:3]), "machine": platform.machine(), "bits": platform.architecture()[0]}))'
if ($LASTEXITCODE -ne 0) { throw 'Server Python is unavailable.' }
$server = $serverJson | ConvertFrom-Json
if ($built.version[0] -ne $server.version[0] -or $built.version[1] -ne $server.version[1] -or $built.machine -ne $server.machine) {
    throw "Bundle Python $($built.version[0]).$($built.version[1])/$($built.machine) does not match server Python $($server.version[0]).$($server.version[1])/$($server.machine). Rebuild the bundle with a matching interpreter."
}

New-Item -ItemType Directory -Path $installFull -ErrorAction Stop | Out-Null
Get-ChildItem -LiteralPath $appSource -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $installFull -Recurse -Force -ErrorAction Stop
}
New-Item -ItemType Directory -Path (Join-Path $installFull 'test_outputs') -ErrorAction Stop | Out-Null

& $PythonExe -m venv (Join-Path $installFull '.venv')
if ($LASTEXITCODE -ne 0) { throw 'Unable to create the server virtual environment.' }
$venvPython = Join-Path $installFull '.venv\Scripts\python.exe'
$projectWheel = @(Get-ChildItem -LiteralPath $wheelhouse -Filter 'comsol_mcp-*.whl' -File)
if ($projectWheel.Count -ne 1) { throw "Expected one project wheel, found $($projectWheel.Count)." }
& $venvPython -m pip install --no-index --find-links $wheelhouse $projectWheel[0].FullName
if ($LASTEXITCODE -ne 0) { throw 'Offline dependency installation failed.' }
& $venvPython -m pip check
if ($LASTEXITCODE -ne 0) { throw 'pip check found an inconsistent environment.' }
Push-Location $installFull
try {
    & $venvPython -c 'import src.server; print("src.server import OK")'
    if ($LASTEXITCODE -ne 0) { throw 'MCP server import smoke test failed.' }
} finally {
    Pop-Location
}

$toml = @"
[mcp_servers.comsol]
command = "$($venvPython.Replace('\', '\\'))"
args = ["-m", "src.server"]
cwd = "$($installFull.Replace('\', '\\'))"
startup_timeout_sec = 60
tool_timeout_sec = 600
enabled = true
required = false
default_tools_approval_mode = "prompt"
"@
$generatedConfig = Join-Path $installFull 'codex.comsol.generated.toml'
Set-Content -LiteralPath $generatedConfig -Value $toml -Encoding utf8

Write-Output "Installed to: $installFull"
Write-Output "Generated Codex snippet: $generatedConfig"
Write-Output 'Next: inspect/backup ~/.codex/config.toml, merge the snippet, run codex mcp list, then execute the COMSOL smoke test.'
