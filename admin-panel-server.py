#!/usr/bin/env python3
"""
Matrix Admin Panel - Mesaj Görüntüleme ve Export
=================================================
Port: 9000
URL: http://localhost:9000
"""

from flask import Flask, render_template_string, jsonify, request, send_file
import psycopg2
from datetime import datetime
import json
import csv
import io

app = Flask(__name__)

# PostgreSQL bağlantısı
DB_CONFIG = {
    'host': 'localhost',
    'database': 'synapse',
    'user': 'synapse_user',
    'password': 'SuperGucluSifre2024!',
    'port': 5432
}

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

# Ana sayfa HTML template
TEMPLATE = '''
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Matrix Admin Panel - Mesaj İzleme</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1600px; margin: 0 auto; }
        .header {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .header h1 { color: #333; margin-bottom: 10px; }
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
        .filters {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .filter-row {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 15px;
        }
        .filter-group { display: flex; flex-direction: column; }
        .filter-group label { color: #666; font-size: 14px; margin-bottom: 5px; }
        .filter-group input, .filter-group select {
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
        }
        button {
            padding: 12px 24px;
            border: none;
            border-radius: 5px;
            font-size: 14px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s;
            margin-right: 10px;
            margin-bottom: 10px;
        }
        .btn-primary { background: #667eea; color: white; }
        .btn-primary:hover { background: #5568d3; transform: translateY(-2px); }
        .btn-success { background: #4CAF50; color: white; }
        .btn-warning { background: #FF9800; color: white; }
        .btn-info { background: #2196F3; color: white; }
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
        .loading { text-align: center; padding: 40px; color: #999; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Matrix Admin Dashboard</h1>
            <p>Tüm mesajları gerçek zamanlı görüntüleyin ve export edin</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <h3>Toplam Mesaj</h3>
                <div class="value" id="totalMessages">0</div>
            </div>
            <div class="stat-card">
                <h3>Toplam Oda</h3>
                <div class="value" id="totalRooms">0</div>
            </div>
            <div class="stat-card">
                <h3>Aktif Kullanıcı</h3>
                <div class="value" id="totalUsers">0</div>
            </div>
            <div class="stat-card">
                <h3>Şifresiz Mesaj</h3>
                <div class="value" id="unencryptedMessages" style="color: #4CAF50;">100%</div>
            </div>
        </div>
        
        <div class="filters">
            <h2>🔍 Filtreler</h2>
            <div class="filter-row">
                <div class="filter-group">
                    <label>Oda ID</label>
                    <input type="text" id="filterRoomId" placeholder="!abc:localhost">
                </div>
                <div class="filter-group">
                    <label>Kullanıcı</label>
                    <input type="text" id="filterSender" placeholder="@1k:localhost">
                </div>
                <div class="filter-group">
                    <label>Limit</label>
                    <input type="number" id="filterLimit" value="100">
                </div>
            </div>
            
            <div class="filter-row">
                <div class="filter-group">
                    <label>Kelime Ara</label>
                    <input type="text" id="searchQuery" placeholder="Mesajlarda ara...">
                </div>
            </div>
            
            <div class="actions">
                <button class="btn-primary" onclick="loadMessages()">📊 Mesajları Yükle</button>
                <button class="btn-success" onclick="exportData('json')">💾 JSON İndir</button>
                <button class="btn-success" onclick="exportData('csv')">📄 CSV İndir</button>
                <button class="btn-warning" onclick="clearFilters()">🔄 Temizle</button>
            </div>
        </div>
        
        <div class="messages-container">
            <h2>💬 Mesajlar</h2>
            <div id="messagesContent">
                <div class="loading">Mesajları yüklemek için yukarıdaki "Mesajları Yükle" butonuna tıklayın</div>
            </div>
        </div>
    </div>
    
    <script>
        async function loadStats() {
            const response = await fetch('/api/stats');
            const stats = await response.json();
            
            document.getElementById('totalMessages').textContent = stats.total_messages;
            document.getElementById('totalRooms').textContent = stats.total_rooms;
            document.getElementById('totalUsers').textContent = stats.total_users;
        }
        
        async function loadMessages() {
            const content = document.getElementById('messagesContent');
            content.innerHTML = '<div class="loading">🔄 Yükleniyor...</div>';
            
            const params = new URLSearchParams({
                room_id: document.getElementById('filterRoomId').value,
                sender: document.getElementById('filterSender').value,
                limit: document.getElementById('filterLimit').value,
                search: document.getElementById('searchQuery').value
            });
            
            try {
                const response = await fetch('/api/messages?' + params);
                const data = await response.json();
                
                if (data.messages.length === 0) {
                    content.innerHTML = '<div class="loading">❌ Mesaj bulunamadı</div>';
                    return;
                }
                
                let html = `
                    <p style="margin-bottom: 15px; color: #666;">
                        Toplam <strong>${data.messages.length}</strong> mesaj bulundu
                    </p>
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
                `;
                
                data.messages.forEach(msg => {
                    html += `
                        <tr>
                            <td class="timestamp">${msg.timestamp}</td>
                            <td class="sender">${msg.sender}</td>
                            <td class="room-name">${msg.room_name || msg.room_id}</td>
                            <td>${msg.message}</td>
                        </tr>
                    `;
                });
                
                html += '</tbody></table>';
                content.innerHTML = html;
                
            } catch (error) {
                content.innerHTML = '<div class="loading">❌ Hata: ' + error.message + '</div>';
            }
        }
        
        async function exportData(format) {
            const params = new URLSearchParams({
                room_id: document.getElementById('filterRoomId').value,
                sender: document.getElementById('filterSender').value,
                limit: document.getElementById('filterLimit').value,
                search: document.getElementById('searchQuery').value,
                format: format
            });
            
            window.location.href = '/api/export?' + params;
        }
        
        function clearFilters() {
            document.getElementById('filterRoomId').value = '';
            document.getElementById('filterSender').value = '';
            document.getElementById('filterLimit').value = '100';
            document.getElementById('searchQuery').value = '';
        }
        
        // Sayfa yüklenince stats'ı yükle
        loadStats();
    </script>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(TEMPLATE)

@app.route('/api/stats')
def get_stats():
    conn = get_db_connection()
    cur = conn.cursor()
    
    # İstatistikleri al
    cur.execute("SELECT COUNT(*) FROM events WHERE type = 'm.room.message'")
    total_messages = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(*) FROM rooms")
    total_rooms = cur.fetchone()[0]
    
    cur.execute("SELECT COUNT(DISTINCT sender) FROM events WHERE type = 'm.room.message'")
    total_users = cur.fetchone()[0]
    
    cur.close()
    conn.close()
    
    return jsonify({
        'total_messages': total_messages,
        'total_rooms': total_rooms,
        'total_users': total_users
    })

@app.route('/api/messages')
def get_messages():
    room_id = request.args.get('room_id', '')
    sender = request.args.get('sender', '')
    limit = int(request.args.get('limit', 100))
    search = request.args.get('search', '')
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # SQL sorgusu oluştur
    conditions = ["e.type = 'm.room.message'"]
    
    if room_id:
        conditions.append(f"e.room_id = '{room_id}'")
    if sender:
        conditions.append(f"e.sender = '{sender}'")
    if search:
        conditions.append(f"ej.json::json->'content'->>'body' LIKE '%{search}%'")
    
    where_clause = " AND ".join(conditions)
    
    query = f"""
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
        WHERE {where_clause}
        ORDER BY e.origin_server_ts DESC
        LIMIT {limit};
    """
    
    cur.execute(query)
    rows = cur.fetchall()
    
    messages = []
    for row in rows:
        messages.append({
            'timestamp': row[0].strftime('%Y-%m-%d %H:%M:%S') if row[0] else '',
            'sender': row[1],
            'room_id': row[2],
            'room_name': row[3] or 'İsimsiz oda',
            'message': row[4]
        })
    
    cur.close()
    conn.close()
    
    return jsonify({'messages': messages})

@app.route('/api/export')
def export_data():
    room_id = request.args.get('room_id', '')
    sender = request.args.get('sender', '')
    limit = int(request.args.get('limit', 10000))
    search = request.args.get('search', '')
    format_type = request.args.get('format', 'json')
    
    conn = get_db_connection()
    cur = conn.cursor()
    
    # SQL sorgusu (get_messages ile aynı)
    conditions = ["e.type = 'm.room.message'"]
    
    if room_id:
        conditions.append(f"e.room_id = '{room_id}'")
    if sender:
        conditions.append(f"e.sender = '{sender}'")
    if search:
        conditions.append(f"ej.json::json->'content'->>'body' LIKE '%{search}%'")
    
    where_clause = " AND ".join(conditions)
    
    query = f"""
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
        WHERE {where_clause}
        ORDER BY e.origin_server_ts ASC
        LIMIT {limit};
    """
    
    cur.execute(query)
    rows = cur.fetchall()
    
    messages = []
    for row in rows:
        messages.append({
            'timestamp': row[0].strftime('%Y-%m-%d %H:%M:%S') if row[0] else '',
            'sender': row[1],
            'room_id': row[2],
            'room_name': row[3] or 'İsimsiz oda',
            'message': row[4]
        })
    
    cur.close()
    conn.close()
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    if format_type == 'json':
        output = io.BytesIO()
        output.write(json.dumps(messages, indent=2, ensure_ascii=False).encode('utf-8'))
        output.seek(0)
        return send_file(
            output,
            mimetype='application/json',
            as_attachment=True,
            download_name=f'messages_{timestamp}.json'
        )
    
    elif format_type == 'csv':
        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=['timestamp', 'sender', 'room_name', 'message'])
        writer.writeheader()
        writer.writerows(messages)
        
        mem = io.BytesIO()
        mem.write(output.getvalue().encode('utf-8-sig'))  # UTF-8 BOM for Excel
        mem.seek(0)
        
        return send_file(
            mem,
            mimetype='text/csv',
            as_attachment=True,
            download_name=f'messages_{timestamp}.csv'
        )
    
    return jsonify({'error': 'Invalid format'}), 400

if __name__ == '__main__':
    print("")
    print("=" * 50)
    print("  MATRIX ADMIN PANEL BAŞLATILIYOR...")
    print("=" * 50)
    print("")
    print("URL: http://localhost:9000")
    print("")
    print("Özellikler:")
    print("  ✅ Tüm mesajları görüntüleme")
    print("  ✅ Filtreleme (oda, kullanıcı, kelime)")
    print("  ✅ JSON export")
    print("  ✅ CSV export (Excel)")
    print("  ✅ Gerçek zamanlı istatistikler")
    print("")
    print("Durdurmak için: Ctrl+C")
    print("=" * 50)
    print("")
    
    app.run(host='0.0.0.0', port=9000, debug=True)

