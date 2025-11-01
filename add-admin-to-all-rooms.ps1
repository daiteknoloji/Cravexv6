# Admin Kullanıcısını Tüm Odalara Ekle
# ======================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ADMIN TUM ODALARA EKLENIYOR..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Admin token al
$body = @{
    type = "m.login.password"
    user = "@admin:localhost"
    password = "Admin@2024!Guclu"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:8008/_matrix/client/r0/login" `
                                        -Method Post `
                                        -Body $body `
                                        -ContentType "application/json"
    $token = $loginResponse.access_token
    Write-Host "[1/3] Admin token alindi" -ForegroundColor Green
} catch {
    Write-Host "HATA: Token alinamadi!" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Tüm odaları listele
$headers = @{
    "Authorization" = "Bearer $token"
}

try {
    Write-Host "[2/3] Odalar listeleniyor..." -ForegroundColor Yellow
    $roomsResponse = Invoke-RestMethod -Uri "http://localhost:8008/_synapse/admin/v1/rooms" `
                                        -Method Get `
                                        -Headers $headers
    
    $rooms = $roomsResponse.rooms
    Write-Host "Toplam $($rooms.Count) oda bulundu" -ForegroundColor White
} catch {
    Write-Host "HATA: Odalar listelenemedi!" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Her odaya admin'i ekle
Write-Host "[3/3] Admin tum odalara ekleniyor..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$errorCount = 0
$alreadyJoinedCount = 0

foreach ($room in $rooms) {
    $roomId = $room.room_id
    $roomName = if ($room.name) { $room.name } else { $room.canonical_alias }
    if (-not $roomName) { $roomName = $roomId }
    
    Write-Host "  Oda: $roomName" -NoNewline
    
    try {
        # Önce normal join dene
        try {
            Invoke-RestMethod -Uri "http://localhost:8008/_matrix/client/r0/rooms/${roomId}/join" `
                              -Method Post `
                              -Headers $headers `
                              -Body "{}" `
                              -ContentType "application/json" `
                              -ErrorAction Stop | Out-Null
            
            Write-Host " - EKLENDI" -ForegroundColor Green
            $successCount++
        } catch {
            # Normal join olmadı, Admin API ile force join dene
            # user_id JSON body'de (query param değil!)
            $joinBody = @{ user_id = "@admin:localhost" } | ConvertTo-Json
            $forceUrl = "http://localhost:8008/_synapse/admin/v1/join/${roomId}"
            
            try {
                Invoke-RestMethod -Uri $forceUrl `
                                  -Method Post `
                                  -Headers $headers `
                                  -Body $joinBody `
                                  -ContentType "application/json" `
                                  -ErrorAction Stop | Out-Null
                
                Write-Host " - ZORLA EKLENDI" -ForegroundColor Yellow
                $successCount++
            } catch {
                # Force join de olmadı, kullanıcıdan davet gerekli
                throw $_
            }
        }
    } catch {
        if ($_.Exception.Message -like "*already*") {
            Write-Host " - ZATEN UYESI" -ForegroundColor Gray
            $alreadyJoinedCount++
        } else {
            Write-Host " - HATA: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
    }
    
    Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "TAMAMLANDI!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Sonuclar:" -ForegroundColor Cyan
Write-Host "  Basariyla eklendi: $successCount" -ForegroundColor Green
Write-Host "  Zaten uyeydi: $alreadyJoinedCount" -ForegroundColor Gray
Write-Host "  Hata: $errorCount" -ForegroundColor Red
Write-Host "  Toplam: $($rooms.Count)" -ForegroundColor White
Write-Host ""
Write-Host "Admin panelde artik tum odalardaki mesajlari gorebilirsiniz!" -ForegroundColor Cyan
Write-Host "http://localhost:5173" -ForegroundColor Gray
Write-Host ""



