# =============================================
# MESAJLARI EXPORT ET (JSON, CSV, EXCEL)
# =============================================

param(
    [string]$Format = "json",  # json, csv, excel, all
    [string]$RoomId = "",      # Belirli oda (boş = tümü)
    [string]$StartDate = "",   # Başlangıç tarihi (YYYY-MM-DD)
    [string]$EndDate = "",     # Bitiş tarihi (YYYY-MM-DD)
    [string]$Sender = "",      # Belirli kullanıcı
    [int]$Limit = 10000        # Maksimum mesaj sayısı
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MESAJ EXPORT SİSTEMİ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Export klasörü oluştur
$exportFolder = "exports"
if (!(Test-Path $exportFolder)) {
    New-Item -ItemType Directory -Path $exportFolder | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# SQL sorgusu oluştur
$whereConditions = @()
$whereConditions += "e.type = 'm.room.message'"

if ($RoomId) {
    $whereConditions += "e.room_id = '$RoomId'"
}

if ($Sender) {
    $whereConditions += "e.sender = '$Sender'"
}

if ($StartDate) {
    $startTs = [DateTimeOffset]::Parse($StartDate).ToUnixTimeMilliseconds()
    $whereConditions += "e.origin_server_ts >= $startTs"
}

if ($EndDate) {
    $endTs = [DateTimeOffset]::Parse($EndDate).ToUnixTimeMilliseconds()
    $whereConditions += "e.origin_server_ts <= $endTs"
}

$whereClause = $whereConditions -join " AND "

$sql = @"
SELECT 
    e.event_id,
    to_timestamp(e.origin_server_ts/1000) as timestamp,
    e.sender,
    e.room_id,
    (SELECT ej2.json::json->'content'->>'name' 
     FROM events e2 
     JOIN event_json ej2 ON e2.event_id = ej2.event_id 
     WHERE e2.room_id = e.room_id 
       AND e2.type = 'm.room.name' 
     ORDER BY e2.origin_server_ts DESC 
     LIMIT 1) as room_name,
    ej.json::json->'content'->>'body' as message,
    ej.json::json->'content'->>'msgtype' as message_type
FROM events e
JOIN event_json ej ON e.event_id = ej.event_id
WHERE $whereClause
ORDER BY e.origin_server_ts ASC
LIMIT $Limit;
"@

Write-Host "SQL Sorgusu hazirlanıyor..." -ForegroundColor Yellow
Write-Host "Filtreler:" -ForegroundColor Gray
if ($RoomId) { Write-Host "  - Oda: $RoomId" -ForegroundColor White }
if ($Sender) { Write-Host "  - Gönderen: $Sender" -ForegroundColor White }
if ($StartDate) { Write-Host "  - Başlangıç: $StartDate" -ForegroundColor White }
if ($EndDate) { Write-Host "  - Bitiş: $EndDate" -ForegroundColor White }
Write-Host "  - Limit: $Limit mesaj" -ForegroundColor White
Write-Host ""

# Veritabanından mesajları al
Write-Host "Mesajlar veritabanından çekiliyor..." -ForegroundColor Yellow

try {
    $result = docker exec matrix-postgres psql -U synapse_user -d synapse -t -A -F "|" -c $sql
    
    if (-not $result) {
        Write-Host "SONUC: Mesaj bulunamadı!" -ForegroundColor Yellow
        exit
    }
    
    # Parse et
    $messages = @()
    foreach ($line in $result) {
        if ($line -match '^([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)') {
            $messages += [PSCustomObject]@{
                EventId = $matches[1].Trim()
                Timestamp = $matches[2].Trim()
                Sender = $matches[3].Trim()
                RoomId = $matches[4].Trim()
                RoomName = $matches[5].Trim()
                Message = $matches[6].Trim()
                MessageType = $matches[7].Trim()
            }
        }
    }
    
    Write-Host "Toplam $($messages.Count) mesaj bulundu" -ForegroundColor Green
    Write-Host ""
    
    if ($messages.Count -eq 0) {
        Write-Host "Export edilecek mesaj yok!" -ForegroundColor Yellow
        exit
    }
    
    # Export formatına göre kaydet
    
    if ($Format -eq "json" -or $Format -eq "all") {
        $jsonFile = "$exportFolder\messages_$timestamp.json"
        $messages | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
        Write-Host "[JSON] Kaydedildi: $jsonFile" -ForegroundColor Green
    }
    
    if ($Format -eq "csv" -or $Format -eq "all") {
        $csvFile = "$exportFolder\messages_$timestamp.csv"
        $messages | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Host "[CSV] Kaydedildi: $csvFile" -ForegroundColor Green
    }
    
    if ($Format -eq "excel" -or $Format -eq "all") {
        # Excel için CSV kullan (Excel CSV'yi açabilir)
        $excelFile = "$exportFolder\messages_$timestamp.xlsx.csv"
        $messages | Export-Csv -Path $excelFile -NoTypeInformation -Encoding UTF8
        Write-Host "[EXCEL] Kaydedildi: $excelFile (Excel'de aç)" -ForegroundColor Green
    }
    
    if ($Format -eq "html" -or $Format -eq "all") {
        # HTML rapor
        $htmlFile = "$exportFolder\messages_$timestamp.html"
        
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Mesaj Raporu - $timestamp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #333; }
        .stats { background: white; padding: 15px; margin: 20px 0; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; background: white; }
        th { background: #4CAF50; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        .sender { color: #2196F3; font-weight: bold; }
        .timestamp { color: #666; font-size: 0.9em; }
        .room { color: #FF9800; }
    </style>
</head>
<body>
    <h1>📊 Matrix Mesaj Raporu</h1>
    <div class="stats">
        <strong>Toplam Mesaj:</strong> $($messages.Count)<br>
        <strong>Export Tarihi:</strong> $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")<br>
        <strong>Format:</strong> HTML
    </div>
    
    <table>
        <thead>
            <tr>
                <th>Tarih/Saat</th>
                <th>Gönderen</th>
                <th>Oda</th>
                <th>Mesaj</th>
            </tr>
        </thead>
        <tbody>
"@
        
        foreach ($msg in $messages) {
            $html += @"
            <tr>
                <td class="timestamp">$($msg.Timestamp)</td>
                <td class="sender">$($msg.Sender)</td>
                <td class="room">$($msg.RoomName)</td>
                <td>$($msg.Message)</td>
            </tr>
"@
        }
        
        $html += @"
        </tbody>
    </table>
</body>
</html>
"@
        
        $html | Out-File -FilePath $htmlFile -Encoding UTF8
        Write-Host "[HTML] Kaydedildi: $htmlFile" -ForegroundColor Green
        
        # HTML'i tarayıcıda aç
        Start-Process $htmlFile
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "EXPORT TAMAMLANDI!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Dosyalar '$exportFolder' klasöründe" -ForegroundColor Cyan
    Write-Host ""
    
    # İstatistikler
    $uniqueSenders = ($messages | Select-Object -ExpandProperty Sender -Unique).Count
    $uniqueRooms = ($messages | Select-Object -ExpandProperty RoomId -Unique).Count
    
    Write-Host "İSTATİSTİKLER:" -ForegroundColor Yellow
    Write-Host "  Toplam mesaj: $($messages.Count)" -ForegroundColor White
    Write-Host "  Benzersiz kullanıcı: $uniqueSenders" -ForegroundColor White
    Write-Host "  Benzersiz oda: $uniqueRooms" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "HATA: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}

