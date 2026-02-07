[CmdletBinding()]
param(
    [string[]]$TargetUrls = @(
        'https://www.google.com/generate_204',
        'https://www.cloudflare.com/cdn-cgi/trace',
        'https://www.microsoft.com'
    ),
    [string[]]$TargetHosts = @(
        '1.1.1.1',
        '8.8.8.8',
        'www.microsoft.com'
    ),
    [int]$PingCount = 5,
    [int]$RequestTimeoutSec = 10,
    [string]$ProfilesRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TestProfiles {
    param([string]$Root)

    $profiles = New-Object System.Collections.Generic.List[string]

    $general = Join-Path $Root 'general.bat'
    if (Test-Path $general) {
        $profiles.Add((Resolve-Path $general).Path)
    }

    $batchCandidates = Get-ChildItem -Path $Root -File -Filter '*.bat' -ErrorAction SilentlyContinue
    foreach ($file in $batchCandidates) {
        if ($file.Name -like 'ALT*' -or $file.Name -like 'FAKE*') {
            $profiles.Add($file.FullName)
        }
    }

    $simpleFakeBatch = Get-ChildItem -Path $Root -File -Filter '*.bat' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -eq 'SIMPLE FAKE' }
    foreach ($file in $simpleFakeBatch) {
        $profiles.Add($file.FullName)
    }

    # Support named services as profile fallback
    $serviceCandidates = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'general' -or $_.Name -like 'ALT*' -or $_.Name -like 'FAKE*' -or $_.Name -eq 'SIMPLE FAKE' }
    foreach ($svc in $serviceCandidates) {
        $profiles.Add("service:$($svc.Name)")
    }

    $profiles |
        Select-Object -Unique |
        Sort-Object
}

function Start-ProfileTemp {
    param([string]$Profile)

    if ($Profile -like 'service:*') {
        $serviceName = $Profile.Substring(8)
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if (-not $service) {
            return @{ Type = 'none'; Started = $false; Id = $null; Name = $Profile }
        }

        $wasRunning = $service.Status -eq 'Running'
        if (-not $wasRunning) {
            Start-Service -Name $serviceName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }

        return @{ Type = 'service'; Started = (-not $wasRunning); Id = $null; Name = $serviceName }
    }

    if (-not (Test-Path $Profile)) {
        return @{ Type = 'none'; Started = $false; Id = $null; Name = $Profile }
    }

    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c',"`"$Profile`"" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
    return @{ Type = 'process'; Started = $true; Id = $process.Id; Name = $Profile }
}

function Stop-ProfileTemp {
    param([hashtable]$Runtime)

    if (-not $Runtime) { return }

    if ($Runtime.Type -eq 'process' -and $Runtime.Started -and $Runtime.Id) {
        Stop-Process -Id $Runtime.Id -Force -ErrorAction SilentlyContinue
    }

    if ($Runtime.Type -eq 'service' -and $Runtime.Started -and $Runtime.Name) {
        Stop-Service -Name $Runtime.Name -Force -ErrorAction SilentlyContinue
    }
}

function Test-TlsHandshake {
    param(
        [string]$Host,
        [int]$Port = 443,
        [int]$TimeoutMs = 5000
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $task = $client.ConnectAsync($Host, $Port)
        if (-not $task.Wait($TimeoutMs)) {
            $client.Dispose()
            return $false
        }

        $ssl = New-Object System.Net.Security.SslStream($client.GetStream(), $false, ({ $true }))
        $authTask = $ssl.AuthenticateAsClientAsync($Host)
        if (-not $authTask.Wait($TimeoutMs)) {
            $ssl.Dispose()
            $client.Dispose()
            return $false
        }

        $ssl.Dispose()
        $client.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

function Get-PingMetrics {
    param(
        [string[]]$Hosts,
        [int]$Count
    )

    $latencies = @()
    $sent = 0
    $received = 0

    foreach ($host in $Hosts) {
        try {
            $replies = Test-Connection -TargetName $host -Count $Count -ErrorAction Stop
            $sent += $Count
            $received += $replies.Count
            $latencies += $replies | ForEach-Object { [double]$_.Latency }
        }
        catch {
            $sent += $Count
        }
    }

    $avgLatency = if ($latencies.Count -gt 0) {
        [math]::Round((($latencies | Measure-Object -Average).Average), 2)
    }
    else { $null }

    $packetLoss = if ($sent -gt 0) {
        [math]::Round((100 * (($sent - $received) / [double]$sent)), 2)
    }
    else { 100 }

    [pscustomobject]@{
        AvgLatencyMs = $avgLatency
        PacketLossPercent = $packetLoss
        PingSent = $sent
        PingReceived = $received
    }
}

function Get-UrlSuccessMetrics {
    param(
        [string[]]$Urls,
        [int]$TimeoutSec
    )

    $total = 0
    $ok = 0

    foreach ($url in $Urls) {
        $total++
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec $TimeoutSec -ErrorAction Stop
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
                $ok++
            }
        }
        catch {
            # keep failed
        }
    }

    $rate = if ($total -gt 0) {
        [math]::Round((100 * ($ok / [double]$total)), 2)
    }
    else { 0 }

    [pscustomobject]@{
        UrlChecks = $total
        UrlSuccess = $ok
        UrlSuccessRate = $rate
    }
}

function Get-TlsMetrics {
    param([string[]]$Urls,[string[]]$Hosts)

    $targetHosts = @()
    foreach ($url in $Urls) {
        try {
            $targetHosts += ([System.Uri]$url).Host
        }
        catch {}
    }
    $targetHosts += $Hosts
    $targetHosts = $targetHosts | Select-Object -Unique

    $total = 0
    $ok = 0
    foreach ($host in $targetHosts) {
        $total++
        if (Test-TlsHandshake -Host $host) {
            $ok++
        }
    }

    $rate = if ($total -gt 0) {
        [math]::Round((100 * ($ok / [double]$total)), 2)
    }
    else { 0 }

    [pscustomobject]@{
        TlsChecks = $total
        TlsSuccess = $ok
        TlsSuccessRate = $rate
    }
}

function Get-ProfileScore {
    param([pscustomobject]$Metrics)

    $latencyScore = if ($null -eq $Metrics.AvgLatencyMs) { 0 } else { [math]::Max(0, 100 - $Metrics.AvgLatencyMs) }
    $successScore = $Metrics.UrlSuccessRate
    $tlsScore = $Metrics.TlsSuccessRate
    $lossPenalty = $Metrics.PacketLossPercent

    $score = (0.35 * $latencyScore) + (0.35 * $successScore) + (0.2 * $tlsScore) + (0.1 * (100 - $lossPenalty))
    [math]::Round($score, 2)
}

function Ensure-LogsDir {
    param([string]$Root)
    $logsPath = Join-Path $Root 'logs'
    if (-not (Test-Path $logsPath)) {
        New-Item -Path $logsPath -ItemType Directory | Out-Null
    }
    $logsPath
}

$profiles = Get-TestProfiles -Root $ProfilesRoot
if (-not $profiles -or $profiles.Count -eq 0) {
    throw "Не найдено профилей для теста (ожидались: general.bat, ALT*, FAKE*, SIMPLE FAKE)."
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($profile in $profiles) {
    Write-Host "=== Тест профиля: $profile ===" -ForegroundColor Cyan

    $runtime = $null
    try {
        $runtime = Start-ProfileTemp -Profile $profile

        $ping = Get-PingMetrics -Hosts $TargetHosts -Count $PingCount
        $url = Get-UrlSuccessMetrics -Urls $TargetUrls -TimeoutSec $RequestTimeoutSec
        $tls = Get-TlsMetrics -Urls $TargetUrls -Hosts $TargetHosts

        $combined = [pscustomobject]@{
            Profile = $profile
            AvgLatencyMs = $ping.AvgLatencyMs
            PacketLossPercent = $ping.PacketLossPercent
            UrlSuccessRate = $url.UrlSuccessRate
            TlsSuccessRate = $tls.TlsSuccessRate
            PingSent = $ping.PingSent
            PingReceived = $ping.PingReceived
            UrlChecks = $url.UrlChecks
            UrlSuccess = $url.UrlSuccess
            TlsChecks = $tls.TlsChecks
            TlsSuccess = $tls.TlsSuccess
        }

        $score = Get-ProfileScore -Metrics $combined
        Add-Member -InputObject $combined -NotePropertyName Score -NotePropertyValue $score

        $results.Add($combined)
    }
    finally {
        Stop-ProfileTemp -Runtime $runtime
    }
}

$sorted = $results | Sort-Object -Property Score -Descending
$best = $sorted | Select-Object -First 1

$report = [pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('s')
    TargetUrls = $TargetUrls
    TargetHosts = $TargetHosts
    Profiles = $sorted
    Recommendation = if ($best) { "Лучший профиль: $($best.Profile)" } else { 'Нет данных' }
}

$logsDir = Ensure-LogsDir -Root $ProfilesRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$textPath = Join-Path $logsDir "test-report-$stamp.txt"
$jsonPath = Join-Path $logsDir "test-report-$stamp.json"

$textLines = @()
$textLines += "Отчет тестирования профилей zapret"
$textLines += "Сгенерировано: $($report.GeneratedAt)"
$textLines += ""
$textLines += "Целевые URL: $($TargetUrls -join ', ')"
$textLines += "Целевые хосты: $($TargetHosts -join ', ')"
$textLines += ""
$textLines += "Рейтинг профилей:"

$rank = 1
foreach ($item in $sorted) {
    $textLines += ("{0}. {1} | Score={2} | Latency={3}ms | URL Success={4}% | TLS Success={5}% | Packet Loss={6}%" -f `
            $rank, $item.Profile, $item.Score, $item.AvgLatencyMs, $item.UrlSuccessRate, $item.TlsSuccessRate, $item.PacketLossPercent)
    $rank++
}

$textLines += ""
$textLines += $report.Recommendation

Set-Content -Path $textPath -Value $textLines -Encoding UTF8
$report | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "Готово. TXT: $textPath"
Write-Host "Готово. JSON: $jsonPath"
Write-Host $report.Recommendation -ForegroundColor Green
