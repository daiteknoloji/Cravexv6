# =============================================
# ŞİFRELİ CANLI MESAJ RAPORU
# =============================================
# Her 30 saniyede güncellenir, şifre korumalı
# =============================================

param(
    [int]$IntervalSeconds = 30,
    [string]$AdminPassword = "Admin@2024!Guclu"
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CANLI MESAJ RAPORU" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Güncelleme: Her $IntervalSeconds saniye" -ForegroundColor Yellow
Write-Host "Şifre: Admin korumalı" -ForegroundColor Yellow
Write-Host ""

$reportFile = "exports\live-report.html"
$iteration = 0

# Export klasörü oluştur
if (!(Test-Path "exports")) {
    New-Item -ItemType Directory -Path "exports" | Out-Null
}

while ($true) {
    $iteration++
    $updateTime = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    
    Write-Host "[$updateTime] Güncelleme #$iteration" -ForegroundColor Cyan
    
    # Mesajları çek
    $sql = @"
SELECT 
    to_timestamp(e.origin_server_ts/1000) as timestamp,
    e.sender,
    e.room_id,
    ej.json::json->'content'->>'body' as message
FROM events e
JOIN event_json ej ON e.event_id = ej.event_id
WHERE e.type = 'm.room.message'
ORDER BY e.origin_server_ts DESC
LIMIT 100;
"@
    
    try {
        $result = docker exec matrix-postgres psql -U synapse_user -d synapse -t -A -F "|" -c $sql
        
        $messages = @()
        foreach ($line in $result) {
            if ($line -match '^([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)') {
                $messages += [PSCustomObject]@{
                    Timestamp = $matches[1].Trim()
                    Sender = $matches[2].Trim()
                    RoomId = $matches[3].Trim()
                    Message = $matches[4].Trim()
                }
            }
        }
        
        # HTML oluştur
        $html = @"
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="$IntervalSeconds">
    <title>🔒 Matrix Admin - Canlı Rapor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        /* Login Screen */
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
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            text-align: center;
            min-width: 400px;
        }
        .login-box h2 { color: #333; margin: 20px 0 10px; }
        .login-box p { color: #666; margin-bottom: 30px; }
        .login-box input {
            width: 100%;
            padding: 15px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
            margin-bottom: 20px;
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
        }
        .login-box button:hover {
            background: #5568d3;
        }
        .error-msg {
            color: #f44336;
            margin-top: 15px;
            display: none;
        }
        
        /* Main Content */
        #mainContent { display: none; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .live-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            background: #4CAF50;
            border-radius: 50%;
            animation: pulse 1.5s infinite;
            margin-right: 10px;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
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
        .messages {
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
        .room { color: #FF9800; }
    </style>
</head>
<body>
    <!-- Login Screen -->
    <div id="loginScreen">
        <div class="login-box">
            <div style="font-size: 64px;">🔒</div>
            <h2>Admin Girişi Gerekli</h2>
            <p>Mesaj raporunu görüntülemek için admin şifresini girin</p>
            <input type="password" id="passwordInput" placeholder="Admin Şifresi" 
                   onkeypress="if(event.key==='Enter') checkPassword()">
            <button onclick="checkPassword()">🔓 Giriş Yap</button>
            <div class="error-msg" id="errorMsg">❌ Yanlış şifre! Tekrar deneyin.</div>
        </div>
    </div>
    
    <!-- Main Content -->
    <div id="mainContent">
        <div class="container">
            <div class="header">
                <h1>
                    <span class="live-indicator"></span>
                    📊 Matrix Canlı Mesaj Raporu
                </h1>
                <p>Otomatik güncelleme: Her $IntervalSeconds saniye | Son: <strong>$updateTime</strong></p>
            </div>
            
            <div class="stats">
                <div class="stat-card">
                    <h3>Toplam Mesaj</h3>
                    <div class="value">$($messages.Count)</div>
                </div>
                <div class="stat-card">
                    <h3>Kullanıcı</h3>
                    <div class="value">$(($messages | Select-Object -ExpandProperty Sender -Unique).Count)</div>
                </div>
                <div class="stat-card">
                    <h3>Oda</h3>
                    <div class="value">$(($messages | Select-Object -ExpandProperty RoomId -Unique).Count)</div>
                </div>
                <div class="stat-card">
                    <h3>Güncelleme</h3>
                    <div class="value" style="font-size: 20px;">#$iteration</div>
                </div>
            </div>
            
            <div class="messages">
                <h2>💬 Son 100 Mesaj</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Tarih/Saat</th>
                            <th>Gönderen</th>
                            <th>Oda ID</th>
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
                            <td class="room">$($msg.RoomId)</td>
                            <td>$($msg.Message)</td>
                        </tr>
"@
        }
        
        $html += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
    
    <script>
        const ADMIN_PASSWORD = '$AdminPassword';
        
        function checkPassword() {
            const input = document.getElementById('passwordInput').value;
            if (input === ADMIN_PASSWORD) {
                document.getElementById('loginScreen').style.display = 'none';
                document.getElementById('mainContent').style.display = 'block';
                sessionStorage.setItem('adminAuth', 'true');
            } else {
                document.getElementById('errorMsg').style.display = 'block';
                document.getElementById('passwordInput').value = '';
            }
        }
        
        window.onload = function() {
            if (sessionStorage.getItem('adminAuth') === 'true') {
                document.getElementById('loginScreen').style.display = 'none';
                document.getElementById('mainContent').style.display = 'block';
            } else {
                document.getElementById('passwordInput').focus();
            }
        };
    </script>
</body>
</html>
"@
        
        $html | Out-File -FilePath $reportFile -Encoding UTF8
        
        Write-Host "              ✅ Güncellendi ($($messages.Count) mesaj)" -ForegroundColor Green
        
        if ($iteration -eq 1) {
            Start-Process $reportFile
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  TARAYICIDA AÇILDI!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "🔒 Admin Şifresi: $AdminPassword" -ForegroundColor Yellow
            Write-Host "🔄 Her $IntervalSeconds saniyede otomatik güncellenir" -ForegroundColor Cyan
            Write-Host ""
        }
        
    } catch {
        Write-Host "              ❌ Hata: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds $IntervalSeconds
}

