[CmdletBinding()]
param(
    [string]$PythonExe = 'python',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$commitFile = Join-Path $repoRoot 'UPSTREAM_COMMIT'
$commit = (Get-Content -Raw -LiteralPath $commitFile).Trim()
if ($commit -notmatch '^[0-9a-f]{40}$') { throw 'UPSTREAM_COMMIT must contain one full 40-character Git commit.' }

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot 'artifacts'
}
$outputFull = [System.IO.Path]::GetFullPath($OutputDirectory)
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$workRoot = Join-Path $repoRoot ".build\$stamp"
$sourceRoot = Join-Path $workRoot 'upstream'
$buildVenv = Join-Path $workRoot 'venv'
$payload = Join-Path $workRoot 'payload'
$wheelhouse = Join-Path $payload 'wheelhouse'

New-Item -ItemType Directory -Path $workRoot, $payload, $wheelhouse, $outputFull -Force | Out-Null

& git clone --no-checkout 'https://github.com/wjc9011/COMSOL_Multiphysics_MCP.git' $sourceRoot
if ($LASTEXITCODE -ne 0) { throw 'Upstream clone failed.' }
& git -C $sourceRoot checkout --detach $commit
if ($LASTEXITCODE -ne 0) { throw "Unable to checkout pinned commit $commit." }
$actualCommit = (& git -C $sourceRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $commit) { throw 'Checked-out commit does not match UPSTREAM_COMMIT.' }

& $PythonExe -m venv $buildVenv
if ($LASTEXITCODE -ne 0) { throw 'Unable to create build virtual environment.' }
$buildPython = Join-Path $buildVenv 'Scripts\python.exe'
& $buildPython -m pip install --upgrade pip wheel
if ($LASTEXITCODE -ne 0) { throw 'Unable to install build tooling.' }
& $buildPython -m pip wheel $sourceRoot --wheel-dir $wheelhouse
if ($LASTEXITCODE -ne 0) { throw 'Wheel build failed.' }

$projectWheel = @(Get-ChildItem -LiteralPath $wheelhouse -Filter 'comsol_mcp-*.whl' -File)
if ($projectWheel.Count -ne 1) { throw "Expected one comsol_mcp wheel, found $($projectWheel.Count)." }

$sourceArchive = Join-Path $workRoot 'upstream-source.zip'
& git -C $sourceRoot archive --format=zip --output=$sourceArchive $commit
if ($LASTEXITCODE -ne 0) { throw 'Unable to archive upstream source.' }
Expand-Archive -LiteralPath $sourceArchive -DestinationPath (Join-Path $payload 'app')

$runtimeJson = & $PythonExe -c 'import json,platform,sys; print(json.dumps({"version": list(sys.version_info[:3]), "machine": platform.machine(), "bits": platform.architecture()[0], "implementation": platform.python_implementation()}, indent=2))'
if ($LASTEXITCODE -ne 0) { throw 'Unable to record Python runtime.' }
Set-Content -LiteralPath (Join-Path $payload 'python-runtime.json') -Value $runtimeJson -Encoding utf8
Set-Content -LiteralPath (Join-Path $payload 'upstream-commit.txt') -Value $commit -Encoding ascii

New-Item -ItemType Directory -Path (Join-Path $payload 'scripts'), (Join-Path $payload 'config') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\Test-Environment.ps1') -Destination (Join-Path $payload 'scripts\Test-Environment.ps1')
Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\Install-OnComsolServer.ps1') -Destination (Join-Path $payload 'scripts\Install-OnComsolServer.ps1')
Copy-Item -LiteralPath (Join-Path $repoRoot 'config\codex.comsol.example.toml') -Destination (Join-Path $payload 'config\codex.comsol.example.toml')
Copy-Item -LiteralPath (Join-Path $repoRoot 'DEPLOYMENT_PLAN.md') -Destination (Join-Path $payload 'DEPLOYMENT_PLAN.md')

$hashLines = Get-ChildItem -LiteralPath $payload -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
        $relative = [System.IO.Path]::GetRelativePath($payload, $_.FullName).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $relative"
    }
Set-Content -LiteralPath (Join-Path $payload 'SHA256SUMS.txt') -Value $hashLines -Encoding ascii

$bundlePath = Join-Path $outputFull "comsol-mcp-bundle-$stamp.zip"
Compress-Archive -Path (Join-Path $payload '*') -DestinationPath $bundlePath -CompressionLevel Optimal
$bundleHash = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$bundlePath.sha256" -Value "$bundleHash  $([System.IO.Path]::GetFileName($bundlePath))" -Encoding ascii

Write-Output "Bundle: $bundlePath"
Write-Output "SHA256: $bundleHash"
Write-Output "Pinned upstream: $commit"

