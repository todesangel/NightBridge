# Базовый тестовый скрипт для проверки окружения zapret на Windows

Write-Host "[test zapret] Checking prerequisites..."

$requirements = @(
    "WinDivert installed",
    "zapret/winws binaries available",
    "PowerShell 5+",
    "Administrator privileges"
)

$requirements | ForEach-Object { Write-Host " - $_" }

Write-Host "[test zapret] Template script completed."
