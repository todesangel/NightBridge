# Проверка готовности NightBridge/zapret к запуску на Windows

$ErrorActionPreference = 'Stop'

function Add-Result {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Details
    )

    $status = if ($Ok) { '[OK]' } else { '[FAIL]' }
    Write-Host "$status $Name - $Details"

    [PSCustomObject]@{
        Name    = $Name
        Success = $Ok
        Details = $Details
    }
}

$results = @()

Write-Host "[NightBridge check] Starting environment validation..."

# 1) ОС и версия PowerShell
$isWindows = $PSVersionTable.PSVersion -and ($env:OS -eq 'Windows_NT' -or $PSVersionTable.Platform -eq 'Win32NT')
$results += Add-Result -Name 'Windows OS' -Ok $isWindows -Details ($(if ($isWindows) { 'Windows detected' } else { 'This script must run on Windows 10/11' }))

$psOk = $PSVersionTable.PSVersion.Major -ge 5
$results += Add-Result -Name 'PowerShell version' -Ok $psOk -Details "Detected $($PSVersionTable.PSVersion)"

# 2) Права администратора
$isAdmin = $false
try {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $isAdmin = $false
}
$results += Add-Result -Name 'Administrator privileges' -Ok $isAdmin -Details ($(if ($isAdmin) { 'Elevated session detected' } else { 'Run PowerShell as Administrator' }))

# 3) Наличие основных файлов
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$requiredFiles = @(
    'service.bat',
    'general.bat',
    'lists\list-general.txt',
    'lists\list-google.txt',
    'lists\list-exclude.txt',
    'ipset\discord.txt',
    'ipset\cloudflare.txt',
    'ipset\google.txt',
    'ipset\youtube.txt'
)

$missing = @()
foreach ($relPath in $requiredFiles) {
    $full = Join-Path $root $relPath
    if (-not (Test-Path -LiteralPath $full)) {
        $missing += $relPath
    }
}
$filesOk = $missing.Count -eq 0
$results += Add-Result -Name 'Required files' -Ok $filesOk -Details ($(if ($filesOk) { 'All required files are present' } else { "Missing: $($missing -join ', ')" }))

# 4) WinDivert
$windivertCandidates = @(
    "$env:WINDIR\System32\WinDivert.dll",
    "$env:WINDIR\SysWOW64\WinDivert.dll",
    (Join-Path $root 'WinDivert.dll'),
    (Join-Path $root 'WinDivert64.sys'),
    (Join-Path $root 'WinDivert32.sys')
)
$windivertFound = $windivertCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
$results += Add-Result -Name 'WinDivert files' -Ok ($windivertFound.Count -gt 0) -Details ($(if ($windivertFound.Count -gt 0) { "Found: $($windivertFound -join ', ')" } else { 'WinDivert files were not found in common locations' }))

# 5) Проверка, что скрипты не оставлены как шаблон
$servicePath = Join-Path $root 'service.bat'
$templateMarkers = @('TODO', 'Replace this echo with your command')
$serviceContent = if (Test-Path -LiteralPath $servicePath) { Get-Content -LiteralPath $servicePath -Raw } else { '' }
$markersFound = @()
foreach ($marker in $templateMarkers) {
    if ($serviceContent -match [Regex]::Escape($marker)) {
        $markersFound += $marker
    }
}

$scriptReady = $markersFound.Count -eq 0
$results += Add-Result -Name 'service.bat readiness' -Ok $scriptReady -Details ($(if ($scriptReady) { 'No template markers detected' } else { "Template markers found: $($markersFound -join ', '). Fill in real bypass commands." }))

# 6) Базовая сеть (без гарантии обхода)
$networkTargets = @('1.1.1.1', '8.8.8.8')
$reachable = @()
foreach ($target in $networkTargets) {
    try {
        if (Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction Stop) {
            $reachable += $target
        }
    } catch {
        # ignore
    }
}
$netOk = $reachable.Count -gt 0
$results += Add-Result -Name 'Baseline network reachability' -Ok $netOk -Details ($(if ($netOk) { "Reachable: $($reachable -join ', ')" } else { 'No test hosts reachable. Check connectivity/firewall.' }))

# Summary
Write-Host "`n[NightBridge check] Summary"
$failed = $results | Where-Object { -not $_.Success }
if ($failed.Count -eq 0) {
    Write-Host '[READY] Environment looks good for further bypass testing.'
    exit 0
}

Write-Host "[NOT READY] Failed checks: $($failed.Count)"
$failed | ForEach-Object { Write-Host " - $($_.Name): $($_.Details)" }
exit 1
