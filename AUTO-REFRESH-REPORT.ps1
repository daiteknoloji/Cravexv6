# =============================================
# OTOMATİK MESAJ RAPORU - CANLI GÜNCELLEME
# =============================================
# Her X saniyede HTML raporu yenilenir
# =============================================

param(
    [int]$IntervalSeconds = 30,  # Her 30 saniyede güncelle
    [string]$RoomId = "",
    [string]$Sender = ""
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  OTOMATİK RAPOR GÜNCELLEMESİ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Güncelleme Aralığı: $IntervalSeconds saniye" -ForegroundColor Yellow
Write-Host "Rapor Dosyası: exports\live-report.html" -ForegroundColor Yellow
Write-Host ""
Write-Host "Servis başlatıldı... (Durdurmak için Ctrl+C)" -ForegroundColor Green
Write-Host ""

# İlk raporu oluştur ve aç
$reportFile = "exports\live-report.html"

$iteration = 0
while ($true) {
    $iteration++
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    Write-Host "[$timestamp] Rapor güncelleniyor... (#$iteration)" -ForegroundColor Cyan
    
    # SQL hazırla
    $whereConditions = @("e.type = 'm.room.message'")
    
    if ($RoomId) {
        $whereConditions += "e.room_id = '$RoomId'"
    }
    if ($Sender) {
        $whereConditions += "e.sender = '$Sender'"
    }
    
    $whereClause = $whereConditions -join " AND "
    
    $sql = @"
SELECT 
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
    ej.json::json->'content'->>'body' as message
FROM events e
JOIN event_json ej ON e.event_id = ej.event_id
WHERE $whereClause
ORDER BY e.origin_server_ts DESC
LIMIT 100;
"@
    
    try {
        $result = docker exec matrix-postgres psql -U synapse_user -d synapse -t -A -F "|" -c $sql
        
        $messages = @()
        foreach ($line in $result) {
            if ($line -match '^([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)') {
                $messages += [PSCustomObject]@{
                    Timestamp = $matches[1].Trim()
                    Sender = $matches[2].Trim()
                    RoomId = $matches[3].Trim()
                    RoomName = $matches[4].Trim()
                    Message = $matches[5].Trim()
                }
            }
        }
        
        # HTML oluştur
        $updateTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        
        $html = @"
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="$IntervalSeconds">
    <title>🔒 Matrix Admin - Canlı Mesaj Raporu</title>
    <style>
        #loginScreen {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
        }
        .login-box {
            background: white;
            padding: 40px;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
            min-width: 350px;
        }
        .login-box h2 {
            color: #333;
            margin-bottom: 10px;
        }
        .login-box p {
            color: #666;
            margin-bottom: 30px;
        }
        .login-box input {
            width: 100%;
            padding: 15px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
            margin-bottom: 20px;
            transition: all 0.3s;
        }
        .login-box input:focus {
            outline: none;
            border-color: #667eea;
        }
        .login-box button {
            width: 100%;
            padding: 15px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s;
        }
        .login-box button:hover {
            background: #5568d3;
            transform: translateY(-2px);
        }
        .error-msg {
            color: #f44336;
            margin-top: 15px;
            display: none;
        }
        #mainContent {
            display: none;
        }
        .lock-icon {
            font-size: 48px;
            margin-bottom: 20px;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        .header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .header h1 { color: #333; margin-bottom: 10px; }
        .live-indicator {
            display: inline-block;
            width: 10px;
            height: 10px;
            background: #4CAF50;
            border-radius: 50%;
            animation: pulse 1.5s infinite;
            margin-right: 10px;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            text-align: center;
        }
        .stat-card h3 { color: #666; font-size: 14px; margin-bottom: 10px; }
        .stat-card .value { font-size: 32px; font-weight: bold; color: #667eea; }
        .messages-container {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        thead { background: #667eea; color: white; }
        th { padding: 12px; text-align: left; }
        td { padding: 12px; border-bottom: 1px solid #f0f0f0; }
        tr:hover { background: #f8f9fa; }
        .sender { color: #2196F3; font-weight: bold; }
        .timestamp { color: #999; font-size: 12px; }
        .room-name { color: #FF9800; }
        .update-time { color: #4CAF50; font-weight: bold; }
    </style>
</head>
<body>
    <div id="mainContent">
    <div class="container">
        <div class="header">
            <h1>
                <span class="live-indicator"></span>
                📊 Matrix Canlı Mesaj Raporu
            </h1>
            <p>Otomatik güncelleme: Her $IntervalSeconds saniyede | Son güncelleme: <span class="update-time">$updateTime</span></p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <h3>Toplam Mesaj</h3>
                <div class="value">$($messages.Count)</div>
            </div>
            <div class="stat-card">
                <h3>Benzersiz Kullanıcı</h3>
                <div class="value">$(($messages | Select-Object -ExpandProperty Sender -Unique).Count)</div>
            </div>
            <div class="stat-card">
                <h3>Benzersiz Oda</h3>
                <div class="value">$(($messages | Select-Object -ExpandProperty RoomId -Unique).Count)</div>
            </div>
            <div class="stat-card">
                <h3>Güncelleme</h3>
                <div class="value" style="font-size: 18px;">#$iteration</div>
            </div>
        </div>
        
        <div class="messages-container">
            <h2>💬 Mesajlar (Son 100)</h2>
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
                        <td class="room-name">$($msg.RoomName)</td>
                        <td>$($msg.Message)</td>
                    </tr>
"@
        }
        
        $html += @"
                </tbody>
            </table>
        </div>
    </div>
    
    <!-- Login Screen -->
    <div id="loginScreen">
        <div class="login-box">
            <div class="lock-icon">🔒</div>
            <h2>Admin Girişi</h2>
            <p>Bu raporu görüntülemek için admin şifresi gerekli</p>
            <input type="password" id="passwordInput" placeholder="Admin Şifresi" onkeypress="if(event.key==='Enter') checkPassword()">
            <button onclick="checkPassword()">🔓 Giriş Yap</button>
            <div class="error-msg" id="errorMsg">❌ Yanlış şifre!</div>
        </div>
    </div>
    
    <script>
        // Admin şifresi (değiştirilebilir)
        const ADMIN_PASSWORD = 'Admin@2024!Guclu';
        
        function checkPassword() {
            const password = document.getElementById('passwordInput').value;
            
            if (password === ADMIN_PASSWORD) {
                // Şifre doğru - içeriği göster
                document.getElementById('loginScreen').style.display = 'none';
                document.getElementById('mainContent').style.display = 'block';
                
                // Session storage'a kaydet (sayfa yenilenince tekrar sormasın)
                sessionStorage.setItem('adminLoggedIn', 'true');
            } else {
                // Şifre yanlış
                document.getElementById('errorMsg').style.display = 'block';
                document.getElementById('passwordInput').value = '';
                document.getElementById('passwordInput').focus();
            }
        }
        
        // Sayfa yüklenince kontrol et
        window.onload = function() {
            if (sessionStorage.getItem('adminLoggedIn') === 'true') {
                // Daha önce giriş yapılmış
                document.getElementById('loginScreen').style.display = 'none';
                document.getElementById('mainContent').style.display = 'block';
            } else {
                // İlk giriş - password iste
                document.getElementById('passwordInput').focus();
            }
        };
    </script>
</body>
</html>
"@
        
        # Dosyaya kaydet
        $html | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "              Rapor güncellendi! ($($messages.Count) mesaj)" -ForegroundColor Green
        
        # İlk seferde tarayıcıda aç
        if ($iteration -eq 1) {
            Start-Process $reportFile
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  TARAYICIDA AÇILDI!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Tarayıcı her $IntervalSeconds saniyede otomatik yenilenecek!" -ForegroundColor Cyan
            Write-Host ""
        }
        
    } catch {
        Write-Host "              HATA: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Start-Sleep -Seconds $IntervalSeconds
}

