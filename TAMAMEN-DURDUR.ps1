# ========================================
# TÜM SERVİSLERİ TAMAMEN DURDUR
# ========================================
# Backend, Frontend ve tüm scriptleri durdurur
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Red
Write-Host "  TÜM SERVİSLER DURDURULUYOR...       " -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""

$projectPath = "C:\Users\Can Cakir\Desktop\www-backup"
Set-Location $projectPath

# 1. Frontend servisleri durdur (Port bazlı)
Write-Host "[1/3] Frontend servisleri durduruluyor..." -ForegroundColor Yellow
Write-Host ""

$ports = @(8080, 5173)
foreach ($port in $ports) {
    $process = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty OwningProcess -First 1
    
    if ($process) {
        $serviceName = if ($port -eq 8080) { "Element Web" } else { "Synapse Admin" }
        Write-Host "   $serviceName durduruluyor (Port $port, PID: $process)..." -ForegroundColor Gray
        Stop-Process -Id $process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Host "   [OK] $serviceName durduruldu" -ForegroundColor Green
    } else {
        $serviceName = if ($port -eq 8080) { "Element Web" } else { "Synapse Admin" }
        Write-Host "   [INFO] $serviceName zaten durmus" -ForegroundColor Gray
    }
}

Write-Host ""

# 2. PowerShell scriptlerini durdur (AUTO-ADD, CANLI-RAPOR vb.)
Write-Host "[2/3] PowerShell scriptleri durduruluyor..." -ForegroundColor Yellow
Write-Host ""

# Tüm PowerShell süreçlerini kontrol et
$psProcesses = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -like "*AUTO*" -or 
    $_.MainWindowTitle -like "*CANLI*" -or
    $_.MainWindowTitle -like "*RAPOR*" -or
    $_.MainWindowTitle -like "*ADMIN*"
}

if ($psProcesses) {
    Write-Host "   Script süreçleri durduruluyor..." -ForegroundColor Gray
    foreach ($proc in $psProcesses) {
        Write-Host "   - PID: $($proc.Id) - $($proc.MainWindowTitle)" -ForegroundColor DarkGray
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "   [OK] Script süreçleri durduruldu" -ForegroundColor Green
} else {
    Write-Host "   [INFO] Çalışan script bulunamadı" -ForegroundColor Gray
}

Write-Host ""

# 3. Docker container'ları durdur
Write-Host "[3/3] Backend servisleri durduruluyor..." -ForegroundColor Yellow
Write-Host ""

Write-Host "   Docker container'lari durduruluyor..." -ForegroundColor Gray
docker-compose down 2>$null

Write-Host "   [OK] Docker container'lari durduruldu" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  TÜM SERVİSLER DURDURULDU!           " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "DURDURULDU:" -ForegroundColor Cyan
Write-Host "  ✓ Element Web (Port 8080)" -ForegroundColor White
Write-Host "  ✓ Synapse Admin (Port 5173)" -ForegroundColor White
Write-Host "  ✓ Auto-Add Servisi" -ForegroundColor White
Write-Host "  ✓ Canlı Rapor" -ForegroundColor White
Write-Host "  ✓ Matrix Synapse (Docker)" -ForegroundColor White
Write-Host "  ✓ PostgreSQL (Docker)" -ForegroundColor White
Write-Host "  ✓ Redis (Docker)" -ForegroundColor White
Write-Host ""

Write-Host "Tekrar başlatmak için:" -ForegroundColor Yellow
Write-Host "  .\BASLAT.ps1" -ForegroundColor Cyan
Write-Host ""

