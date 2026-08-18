[CmdletBinding()]
param(
    [ValidateSet('Build', 'Server')]
    [string]$Role = 'Build',
    [string]$PythonExe = 'python',
    [string]$ComsolRoot
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

$comsolExecutables = [System.Collections.Generic.List[string]]::new()

# 1. Explicit root supplied by the caller.
if ($ComsolRoot) {
    foreach ($root in @($ComsolRoot, ([IO.Path]::Combine($ComsolRoot, 'Multiphysics')))) {
        $candidate = [IO.Path]::Combine($root, 'bin', 'win64', 'comsol.exe')
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $comsolExecutables.Add((Resolve-Path -LiteralPath $candidate).Path)
        }
    }
}

# 2. Windows registry, which is also how MPh normally discovers COMSOL.
$registryRoot = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Comsol'
if (Test-Path -LiteralPath $registryRoot) {
    Get-ChildItem -LiteralPath $registryRoot -ErrorAction SilentlyContinue | ForEach-Object {
        $installRoot = (Get-ItemProperty -LiteralPath $_.PSPath -Name COMSOLROOT -ErrorAction SilentlyContinue).COMSOLROOT
        if ($installRoot) {
            $candidate = [IO.Path]::Combine($installRoot, 'bin', 'win64', 'comsol.exe')
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $comsolExecutables.Add((Resolve-Path -LiteralPath $candidate).Path)
            }
        }
    }
}

# 3. PATH, including non-standard installations such as T:\Comsol\... .
Get-Command comsol.exe -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object {
    if (Test-Path -LiteralPath $_.Source -PathType Leaf) {
        $comsolExecutables.Add((Resolve-Path -LiteralPath $_.Source).Path)
    }
}

# 4. Standard Windows install roots as a final fallback.
foreach ($version in '60', '61', '62', '63', '64') {
    $candidate = "C:\Program Files\COMSOL\COMSOL$version\Multiphysics\bin\win64\comsol.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $comsolExecutables.Add((Resolve-Path -LiteralPath $candidate).Path)
    }
}
$foundComsol = @($comsolExecutables | Sort-Object -Unique)

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
    throw 'No COMSOL executable was found via -ComsolRoot, HKLM\SOFTWARE\Comsol, PATH, or standard install roots.'
}
