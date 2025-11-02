# ========================================
# MATRIX FULL STACK - LOCAL CALISTIRMA
# ========================================
# Bu script tum servisleri local'de baslatir
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MATRIX FULL STACK BASLATILIYOR...   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Proje dizinine git
$projectPath = Split-Path -Parent $PSCommandPath
Set-Location $projectPath

Write-Host "[1/4] Docker Desktop kontrol ediliyor..." -ForegroundColor Yellow
Write-Host ""

# Docker'in calisip calismadigini kontrol et
try {
    $dockerStatus = docker ps 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   [HATA] Docker Desktop calismyor!" -ForegroundColor Red
        Write-Host "   Lutfen Docker Desktop'i baslatin ve tekrar deneyin." -ForegroundColor Yellow
        Write-Host ""
        pause
        exit
    }
    Write-Host "   [OK] Docker Desktop calisiyor" -ForegroundColor Green
} catch {
    Write-Host "   [HATA] Docker Desktop bulunamadi!" -ForegroundColor Red
    Write-Host "   Lutfen Docker Desktop'i yükleyin." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit
}

Write-Host ""
Write-Host "[2/4] Backend servisleri baslatiliyor..." -ForegroundColor Yellow
Write-Host ""

# Backend'in calisip calismadigini kontrol et
$synapseRunning = docker ps --filter "name=matrix-synapse" --filter "status=running" -q

if ($synapseRunning) {
    Write-Host "   [OK] Backend zaten calisiyor!" -ForegroundColor Green
} else {
    Write-Host "   Backend container'lari baslatiliyor..." -ForegroundColor Gray
    docker-compose up -d
    
    Write-Host "   Synapse'in baslamasini bekliyoruz..." -ForegroundColor Gray
    Start-Sleep -Seconds 8
    
    # Health check
    $maxRetries = 10
    $retryCount = 0
    $healthy = $false
    
    while (-not $healthy -and $retryCount -lt $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8008/health" -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $healthy = $true
            }
        } catch {
            Start-Sleep -Seconds 3
            $retryCount++
            Write-Host "   Bekleniyor... ($retryCount/$maxRetries)" -ForegroundColor Gray
        }
    }
    
    if ($healthy) {
        Write-Host "   [OK] Backend baslatildi ve saglikli!" -ForegroundColor Green
    } else {
        Write-Host "   [UYARI] Backend yavas basladi, devam ediliyor..." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[3/4] Frontend servisleri baslatiliyor..." -ForegroundColor Yellow
Write-Host ""

# Element Web'i kontrol et
$elementRunning = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($elementRunning) {
    Write-Host "   [OK] Element Web zaten calisiyor (Port 8080)" -ForegroundColor Green
} else {
    Write-Host "   Element Web baslatiliyor (Port 8080)..." -ForegroundColor Gray
    Write-Host "   [YENi TERMINAL] Element Web penceresi acilacak..." -ForegroundColor Cyan
    
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "cd '$projectPath\www\element-web'; " +
        "Write-Host ''; " +
        "Write-Host '========================================' -ForegroundColor Green; " +
        "Write-Host '  ELEMENT WEB (Mesajlasma Arayuzu)    ' -ForegroundColor Green; " +
        "Write-Host '========================================' -ForegroundColor Green; " +
        "Write-Host ''; " +
        "Write-Host 'Port: 8080' -ForegroundColor Yellow; " +
        "Write-Host 'URL: http://localhost:8080' -ForegroundColor Cyan; " +
        "Write-Host ''; " +
        "Write-Host 'Baslatiliyor...' -ForegroundColor White; " +
        "Write-Host ''; " +
        "yarn start"
    )
    
    Start-Sleep -Seconds 2
    Write-Host "   [OK] Element Web terminal'i acildi" -ForegroundColor Green
}

# Synapse Admin'i kontrol et
$adminRunning = Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue
if ($adminRunning) {
    Write-Host "   [OK] Synapse Admin zaten calisiyor (Port 5173)" -ForegroundColor Green
} else {
    Write-Host "   Synapse Admin baslatiliyor (Port 5173)..." -ForegroundColor Gray
    Write-Host "   [YENi TERMINAL] Synapse Admin penceresi acilacak..." -ForegroundColor Cyan
    
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "cd '$projectPath\www\admin'; " +
        "Write-Host ''; " +
        "Write-Host '========================================' -ForegroundColor Green; " +
        "Write-Host '  SYNAPSE ADMIN (Yonetim Paneli)      ' -ForegroundColor Green; " +
        "Write-Host '========================================' -ForegroundColor Green; " +
        "Write-Host ''; " +
        "Write-Host 'Port: 5173' -ForegroundColor Yellow; " +
        "Write-Host 'URL: http://localhost:5173' -ForegroundColor Cyan; " +
        "Write-Host ''; " +
        "Write-Host 'Baslatiliyor...' -ForegroundColor White; " +
        "Write-Host ''; " +
        "yarn start"
    )
    
    Start-Sleep -Seconds 2
    Write-Host "   [OK] Synapse Admin terminal'i acildi" -ForegroundColor Green
}

Write-Host ""
Write-Host "[4/4] Servisler kontrol ediliyor..." -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 3

# Backend kontrol
$backend = docker ps --filter "name=matrix-synapse" --filter "status=running" -q
if ($backend) {
    Write-Host "   [OK] Backend (Synapse)" -ForegroundColor Green
} else {
    Write-Host "   [X] Backend (Synapse)" -ForegroundColor Red
}

# PostgreSQL kontrol
$postgres = docker ps --filter "name=matrix-postgres" --filter "status=running" -q
if ($postgres) {
    Write-Host "   [OK] PostgreSQL" -ForegroundColor Green
} else {
    Write-Host "   [X] PostgreSQL" -ForegroundColor Red
}

# Redis kontrol
$redis = docker ps --filter "name=matrix-redis" --filter "status=running" -q
if ($redis) {
    Write-Host "   [OK] Redis" -ForegroundColor Green
} else {
    Write-Host "   [X] Redis" -ForegroundColor Red
}

# Docker Admin kontrol
$dockerAdmin = docker ps --filter "name=synapse-admin-ui" --filter "status=running" -q
if ($dockerAdmin) {
    Write-Host "   [OK] Docker Admin Panel" -ForegroundColor Green
} else {
    Write-Host "   [X] Docker Admin Panel" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  TUM SERVISLER BASLATILDI!           " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "ERISIM BILGILERI:" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. ELEMENT WEB (Mesajlasma):" -ForegroundColor Yellow
Write-Host "   URL: " -NoNewline -ForegroundColor White
Write-Host "http://localhost:8080" -ForegroundColor Cyan
Write-Host "   Durum: Frontend terminal penceresinde basladi" -ForegroundColor Gray
Write-Host "   Bekleme: 30-60 saniye (ilk acilis)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "2. SYNAPSE ADMIN (Yonetim):" -ForegroundColor Yellow
Write-Host "   URL: " -NoNewline -ForegroundColor White
Write-Host "http://localhost:5173" -ForegroundColor Cyan
Write-Host "   Durum: Frontend terminal penceresinde basladi" -ForegroundColor Gray
Write-Host "   Bekleme: 5-10 saniye" -ForegroundColor DarkGray
Write-Host ""

Write-Host "3. DOCKER ADMIN PANEL:" -ForegroundColor Yellow
Write-Host "   URL: " -NoNewline -ForegroundColor White
Write-Host "http://localhost:8082" -ForegroundColor Cyan
Write-Host "   Durum: Docker container'da calisiyor" -ForegroundColor Gray
Write-Host ""

Write-Host "4. BACKEND API:" -ForegroundColor Yellow
Write-Host "   URL: " -NoNewline -ForegroundColor White
Write-Host "http://localhost:8008" -ForegroundColor Cyan
Write-Host "   Durum: Docker container'da calisiyor" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "GIRIS BILGILERI:" -ForegroundColor Yellow
Write-Host "================" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Username: " -NoNewline -ForegroundColor White
Write-Host "admin" -ForegroundColor Green
Write-Host "  Password: " -NoNewline -ForegroundColor White
Write-Host "Admin@2024!Guclu" -ForegroundColor Green
Write-Host "  Homeserver: " -NoNewline -ForegroundColor White
Write-Host "http://localhost:8008" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "NOTLAR:" -ForegroundColor Yellow
Write-Host "=======" -ForegroundColor Yellow
Write-Host "  - Element Web ilk acilista yavas olabilir (webpack build)" -ForegroundColor White
Write-Host "  - Frontend terminal pencerelerini KAPATMAYIN!" -ForegroundColor Red
Write-Host "  - Durdurmak icin: " -NoNewline -ForegroundColor White
Write-Host ".\DURDUR.ps1" -ForegroundColor Cyan
Write-Host "  - Durum kontrolu: " -NoNewline -ForegroundColor White
Write-Host ".\DURUM.ps1" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Basariyla baslatildi! Tarayicidan girisi yapabilirsiniz." -ForegroundColor White
Write-Host ""

