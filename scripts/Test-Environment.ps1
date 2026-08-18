[CmdletBinding()]
param(
    [ValidateSet('Build', 'Server')]
    [string]$Role = 'Build',
    [string]$PythonExe = 'python'
)

$ErrorActionPreference = 'Stop'

function Invoke-Captured {
    param([string]$FilePath, [string[]]$Arguments)
    try {
        $output = & $FilePath @Arguments 2>&1
        [pscustomobject]@{ Found = $true; ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
    } catch {
        [pscustomobject]@{ Found = $false; ExitCode = $null; Output = $_.Exception.Message }
    }
}

$python = Invoke-Captured -FilePath $PythonExe -Arguments @('-c', 'import platform,sys;print(sys.version.split()[0],platform.machine(),platform.architecture()[0],sep=chr(124))')
$git = Invoke-Captured -FilePath 'git' -Arguments @('--version')
$codex = Invoke-Captured -FilePath 'codex' -Arguments @('--version')

$comsolRoots = @(
    'C:\Program Files\COMSOL',
    'C:\Program Files\COMSOL\COMSOL60',
    'C:\Program Files\COMSOL\COMSOL61',
    'C:\Program Files\COMSOL\COMSOL62',
    'C:\Program Files\COMSOL\COMSOL63',
    'C:\Program Files\COMSOL\COMSOL64'
)
$foundComsol = @($comsolRoots | Where-Object { Test-Path -LiteralPath $_ -PathType Container })

[pscustomobject]@{
    Role = $Role
    Python = $python.Output
    PythonOK = $python.Found -and $python.ExitCode -eq 0
    Git = $git.Output
    GitOK = $git.Found -and $git.ExitCode -eq 0
    Codex = $codex.Output
    CodexOK = $codex.Found -and $codex.ExitCode -eq 0
    ComsolPaths = ($foundComsol -join '; ')
    ComsolFound = $foundComsol.Count -gt 0
    TDriveFound = Test-Path -LiteralPath 'T:\'
} | Format-List

if (-not $python.Found -or $python.ExitCode -ne 0) { throw 'Python is unavailable.' }
$runtime = @($python.Output -split '\|')
if ($runtime.Count -ne 3) { throw "Unexpected Python runtime output: $($python.Output)" }
$version = @($runtime[0] -split '\.')
if ($version.Count -lt 2 -or [int]$version[0] -lt 3 -or ([int]$version[0] -eq 3 -and [int]$version[1] -lt 10)) {
    throw "Python 3.10+ is required; found $($runtime[0])."
}
if (-not $git.Found -or $git.ExitCode -ne 0) { throw 'Git is unavailable.' }
if ($Role -eq 'Server' -and $foundComsol.Count -eq 0) {
    throw 'No COMSOL installation was found in the checked common paths. Verify the actual path; do not guess or modify system variables.'
}
