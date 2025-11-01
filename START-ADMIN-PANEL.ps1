# =============================================
# ADMIN PANEL WEB SERVER BAŞLAT
# =============================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ADMIN PANEL BAŞLATILIYOR..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Python kurulu mu kontrol et
try {
    $pythonVersion = python --version 2>&1
    Write-Host "[1/3] Python kontrol: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[HATA] Python bulunamadı!" -ForegroundColor Red
    Write-Host "Python'u indirin: https://www.python.org/downloads/" -ForegroundColor Yellow
    exit
}

# Flask kurulu mu kontrol et
Write-Host "[2/3] Flask kontrol ediliyor..." -ForegroundColor Yellow

try {
    python -c "import flask" 2>$null
    Write-Host "      Flask kurulu" -ForegroundColor Green
} catch {
    Write-Host "      Flask kurulu değil, yükleniyor..." -ForegroundColor Yellow
    pip install Flask psycopg2-binary
}

# Admin panel'i başlat
Write-Host "[3/3] Admin panel başlatılıyor..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "PANEL BAŞLATILDI!" -ForegroundColor Green
Write-Host ""
Write-Host "URL: http://localhost:9000" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tarayıcınızda açın ve mesajları görüntüleyin!" -ForegroundColor White
Write-Host ""
Write-Host "Durdurmak için: Ctrl+C" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

python admin-panel-server.py

