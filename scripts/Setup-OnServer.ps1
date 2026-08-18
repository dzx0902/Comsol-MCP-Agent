[CmdletBinding()]
param(
    [string]$PythonExe = 'python',
    [string]$ExpectedPythonVersion = '3.13.5'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$appRoot = Join-Path $repoRoot 'vendor\COMSOL_Multiphysics_MCP'

function Get-PythonRuntime {
    param([string]$Executable)

    # Do not embed quoted Python string literals here. Windows PowerShell 5.1 can
    # strip those quotes while constructing a native-process command line.
    $output = & $Executable -c 'import platform,sys;print(sys.version.split()[0],platform.machine(),platform.architecture()[0],sep=chr(124))'
    if ($LASTEXITCODE -ne 0) { throw "Python is unavailable: $Executable" }
    $fields = @($output -split '\|')
    if ($fields.Count -ne 3) { throw "Unexpected Python runtime output: $output" }
    [pscustomobject]@{ Version = $fields[0]; Machine = $fields[1]; Bits = $fields[2] }
}

$runtime = Get-PythonRuntime -Executable $PythonExe
if ($runtime.version -ne $ExpectedPythonVersion) {
    throw "Expected Python $ExpectedPythonVersion, found $($runtime.version)."
}
if ($runtime.machine -ne 'AMD64' -or $runtime.bits -ne '64bit') {
    throw "Expected AMD64/64bit Python, found $($runtime.machine)/$($runtime.bits)."
}

& (Join-Path $PSScriptRoot 'Test-Environment.ps1') -Role Server -PythonExe $PythonExe

& git -C $repoRoot submodule sync --recursive
if ($LASTEXITCODE -ne 0) { throw 'git submodule sync failed.' }
& git -C $repoRoot submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw 'git submodule update failed.' }

$pyproject = Join-Path $appRoot 'pyproject.toml'
if (-not (Test-Path -LiteralPath $pyproject -PathType Leaf)) {
    throw "MCP source is missing: $pyproject"
}

$venvRoot = Join-Path $appRoot '.venv'
$venvPython = Join-Path $venvRoot 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    & $PythonExe -m venv $venvRoot
    if ($LASTEXITCODE -ne 0) { throw 'Virtual environment creation failed.' }
}

$venvRuntime = Get-PythonRuntime -Executable $venvPython
if ($venvRuntime.version -ne $ExpectedPythonVersion -or $venvRuntime.machine -ne 'AMD64' -or $venvRuntime.bits -ne '64bit') {
    throw "Existing virtual environment does not match $ExpectedPythonVersion AMD64/64bit. Move it aside after confirming the path, then rerun setup."
}

& $venvPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw 'pip upgrade failed.' }
& $venvPython -m pip install -e $appRoot
if ($LASTEXITCODE -ne 0) { throw 'COMSOL MCP dependency installation failed.' }
& $venvPython -m pip check
if ($LASTEXITCODE -ne 0) { throw 'pip check found an inconsistent environment.' }
& $venvPython -c 'import mph,mcp,src.server'
if ($LASTEXITCODE -ne 0) { throw 'COMSOL MCP import smoke test failed.' }
Write-Output 'COMSOL MCP imports OK'

Write-Output "COMSOL MCP source: $appRoot"
Write-Output "Python: $venvPython"
Write-Output 'Installation complete. COMSOL license/session verification is the next step.'
