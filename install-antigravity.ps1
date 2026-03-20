# Antigravity Claude Proxy — Windows Install Script
# Run as Administrator in PowerShell

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Пожалуйста, запустите PowerShell от имени Администратора!" -ForegroundColor Red
    exit 1
}

$ErrorActionPreference = "Stop"
Write-Host "=== Antigravity Claude Proxy ===" -ForegroundColor Cyan

try {
    $v = node --version
    Write-Host "Node.js: $v" -ForegroundColor Green
} catch {
    Write-Host "Node.js не найден! Скачай с https://nodejs.org" -ForegroundColor Red
    exit 1
}

Write-Host "Устанавливаем пакет..." -ForegroundColor Yellow
npm install -g antigravity-claude-proxy@2.8.1

$npmRoot = npm root -g
$installDir = Join-Path $npmRoot "antigravity-claude-proxy"

Write-Host "Применяем патчи для ролевухи..." -ForegroundColor Yellow
$patchUrl = "https://raw.githubusercontent.com/LGranted/antigravity-claude-proxy/master/patch.js"
$patchPath = Join-Path $env:TEMP "patch.js"
Invoke-WebRequest -Uri $patchUrl -OutFile $patchPath
node $patchPath "$installDir"

Write-Host "Открываем порт 8080..." -ForegroundColor Yellow
netsh advfirewall firewall delete rule name="Antigravity" 2>$null
netsh advfirewall firewall add rule name="Antigravity" dir=in action=allow protocol=TCP localport=8080 | Out-Null

Write-Host ""
Write-Host "=== Готово! ===" -ForegroundColor Cyan
Write-Host "Добавь аккаунт:" -ForegroundColor Yellow
Write-Host "  antigravity-claude-proxy accounts add"
Write-Host "Запуск:" -ForegroundColor Yellow
Write-Host "  antigravity-claude-proxy start"
Write-Host "Подключение в ST: http://localhost:8080/v1" -ForegroundColor Yellow
