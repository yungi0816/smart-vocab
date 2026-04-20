$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverDir = Join-Path $root "server"
$port = if ($env:PORT) { $env:PORT } else { "3000" }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Smart Vocab Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($p in @($port)) {
    $procIds = netstat -ano | Select-String ":$p\s" | ForEach-Object {
        ($_ -split '\s+')[-1]
    } | Where-Object { $_ -match '^\d+$' -and $_ -ne '0' } | Sort-Object -Unique

    foreach ($procId in $procIds) {
        Stop-Process -Id ([int]$procId) -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped process on port $p (PID $procId)" -ForegroundColor DarkGray
    }
}

Set-Location $serverDir

if (-not (Test-Path "node_modules")) {
    Write-Host "Installing server dependencies..." -ForegroundColor Yellow
    npm install
}

Write-Host "Starting API server at http://localhost:$port" -ForegroundColor Green
npm start
