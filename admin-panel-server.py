#!/usr/bin/env python3
"""
Cravex Admin Panel - Enterprise Edition
========================================
Port: 9000
URL: http://localhost:9000
Login: admin / admin123
"""

from flask import Flask, render_template_string, jsonify, request, send_file, session, redirect, url_for
import psycopg2
from datetime import datetime
import json
import csv
import io
from functools import wraps

app = Flask(__name__)
app.secret_key = 'cravex-admin-secret-key-2024'

# PostgreSQL bağlantısı
DB_CONFIG = {
    'host': 'localhost',
    'database': 'synapse',
    'user': 'synapse_user',
    'password': 'SuperGucluSifre2024!',
    'port': 5432
}

# Admin kullanıcı bilgileri
ADMIN_USERNAME = 'admin'
ADMIN_PASSWORD = 'admin123'

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

# Login required decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Login Sayfası HTML
LOGIN_TEMPLATE = '''
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cravex Admin Panel - Giriş</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0f1419;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            background: #1a1f2e;
            padding: 50px 60px;
            border-radius: 12px;
            border: 1px solid #2a3441;
            width: 100%;
            max-width: 420px;
        }
        .logo {
            text-align: center;
            margin-bottom: 40px;
        }
        .logo h1 {
            color: #ffffff;
            font-size: 28px;
            font-weight: 600;
            margin-bottom: 8px;
            letter-spacing: -0.5px;
        }
        .logo p {
            color: #8b92a0;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 24px;
        }
        .form-group label {
            display: block;
            color: #c4c9d4;
            font-size: 13px;
            font-weight: 500;
            margin-bottom: 8px;
        }
        .form-group input {
            width: 100%;
            padding: 12px 16px;
            border: 1px solid #2a3441;
            border-radius: 6px;
            font-size: 15px;
            transition: all 0.2s;
            background: #0f1419;
            color: #ffffff;
        }
        .form-group input:focus {
            outline: none;
            border-color: #4a90e2;
            background: #1a1f2e;
        }
        .login-btn {
            width: 100%;
            padding: 14px;
            background: #4a90e2;
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 15px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
        }
        .login-btn:hover {
            background: #3a7bc8;
        }
        .error {
            background: rgba(239, 68, 68, 0.1);
            color: #ef4444;
            padding: 12px 16px;
            border-radius: 6px;
            margin-bottom: 20px;
            font-size: 14px;
            border: 1px solid rgba(239, 68, 68, 0.2);
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #64748b;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">
            <h1><i class="fas fa-shield-alt"></i> Cravex Admin</h1>
            <p>Admin Panel</p>
        </div>
        
        {% if error %}
        <div class="error"><i class="fas fa-exclamation-circle"></i> {{ error }}</div>
        {% endif %}
        
        <form method="POST" action="/login">
            <div class="form-group">
                <label>Kullanıcı Adı</label>
                <input type="text" name="username" required autofocus placeholder="admin">
            </div>
            
            <div class="form-group">
                <label>Şifre</label>
                <input type="password" name="password" required placeholder="••••••••">
            </div>
            
            <button type="submit" class="login-btn">Giriş Yap</button>
        </form>
        
        <div class="footer">
            © 2024 Cravex Communication
        </div>
    </div>
</body>
</html>
'''

# Ana Dashboard HTML (Minimal Tasarım + Pagination)
DASHBOARD_TEMPLATE = '''
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cravex Admin Panel</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0f1419;
            color: #e4e6eb;
        }
        
        /* Header */
        .header {
            background: #1a1f2e;
            border-bottom: 1px solid #2a3441;
            padding: 0 32px;
            height: 70px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 100;
        }
        .header-left { display: flex; align-items: center; gap: 16px; }
        .header h1 { 
            font-size: 20px; 
            font-weight: 600; 
            color: #ffffff;
            letter-spacing: -0.3px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .header h1 i {
            font-size: 48px;
            color: #4a90e2;
        }
        .header-right { display: flex; align-items: center; gap: 16px; }
        .user-info {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 6px 14px;
            background: rgba(255,255,255,0.05);
            border-radius: 6px;
            border: 1px solid #2a3441;
        }
        .user-avatar {
            width: 28px;
            height: 28px;
            background: #4a90e2;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 600;
            font-size: 12px;
        }
        .user-name { font-size: 13px; color: #c4c9d4; }
        .logout-btn {
            padding: 6px 14px;
            background: rgba(239, 68, 68, 0.1);
            color: #ef4444;
            border: 1px solid rgba(239, 68, 68, 0.2);
            border-radius: 6px;
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
        }
        .logout-btn:hover { background: rgba(239, 68, 68, 0.15); }
        
        /* Container */
        .container { max-width: 1600px; margin: 0 auto; padding: 32px; }
        
        /* Stats Cards */
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 16px;
            margin-bottom: 32px;
        }
        .stat-card {
            background: #1a1f2e;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #2a3441;
        }
        .stat-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .stat-icon {
            width: 36px;
            height: 36px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
            background: rgba(255,255,255,0.05);
            color: #8b92a0;
        }
        .stat-label { 
            font-size: 12px; 
            color: #8b92a0; 
            font-weight: 500;
            margin-bottom: 8px;
        }
        .stat-value { 
            font-size: 28px; 
            font-weight: 600; 
            color: #ffffff;
        }
        
        /* Filters */
        .filters-card {
            background: #1a1f2e;
            padding: 24px;
            border-radius: 8px;
            border: 1px solid #2a3441;
            margin-bottom: 20px;
        }
        .filters-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .filters-header h2 { 
            font-size: 16px; 
            font-weight: 600;
            color: #ffffff;
        }
        .filter-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-bottom: 20px;
        }
        .filter-group label {
            display: block;
            color: #8b92a0;
            font-size: 12px;
            font-weight: 500;
            margin-bottom: 6px;
        }
        .filter-group input {
            width: 100%;
            padding: 8px 12px;
            border: 1px solid #2a3441;
            border-radius: 6px;
            font-size: 13px;
            background: #0f1419;
            color: #ffffff;
            transition: all 0.2s;
        }
        .filter-group input:focus {
            outline: none;
            border-color: #4a90e2;
        }
        .filter-group input::placeholder {
            color: #64748b;
        }
        
        /* Buttons */
        .btn-group {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        button {
            padding: 8px 16px;
            border: none;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        .btn-primary { 
            background: #4a90e2; 
            color: white;
        }
        .btn-primary:hover { background: #3a7bc8; }
        .btn-secondary { 
            background: rgba(255,255,255,0.05);
            color: #c4c9d4;
            border: 1px solid #2a3441;
        }
        .btn-secondary:hover { background: rgba(255,255,255,0.08); }
        button:disabled {
            opacity: 0.4;
            cursor: not-allowed;
        }
        
        /* Messages Table */
        .messages-card {
            background: #1a1f2e;
            border-radius: 8px;
            border: 1px solid #2a3441;
            overflow: hidden;
        }
        .messages-header {
            padding: 20px 24px;
            border-bottom: 1px solid #2a3441;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .messages-header h2 { 
            font-size: 16px; 
            font-weight: 600;
            color: #ffffff;
        }
        .messages-body { padding: 0; }
        
        /* Pagination */
        .pagination {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .pagination-info {
            font-size: 13px;
            color: #8b92a0;
            padding: 0 12px;
        }
        .pagination-info strong {
            color: #ffffff;
        }
        .page-btn {
            padding: 6px 12px;
            background: rgba(255,255,255,0.05);
            color: #c4c9d4;
            border: 1px solid #2a3441;
            border-radius: 6px;
            font-size: 13px;
            cursor: pointer;
            transition: all 0.2s;
        }
        .page-btn:hover:not(:disabled) {
            background: rgba(255,255,255,0.08);
        }
        .page-btn:disabled {
            opacity: 0.3;
            cursor: not-allowed;
        }
        
        table { width: 100%; border-collapse: collapse; }
        thead { 
            background: rgba(255,255,255,0.02);
            border-bottom: 1px solid #2a3441;
        }
        th { 
            padding: 12px 20px; 
            text-align: left; 
            font-size: 11px;
            font-weight: 600;
            color: #8b92a0;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        td { 
            padding: 14px 20px; 
            border-bottom: 1px solid #2a3441;
            font-size: 13px;
            color: #c4c9d4;
        }
        tr:hover { background: rgba(255,255,255,0.02); }
        .sender { 
            color: #4a90e2; 
            font-weight: 500;
            font-family: 'Courier New', monospace;
        }
        .timestamp { 
            color: #8b92a0; 
            font-size: 12px;
        }
        .room-name { 
            color: #8b92a0;
        }
        .recipient {
            color: #10b981;
            font-weight: 500;
            font-family: 'Courier New', monospace;
        }
        .recipient-group {
            color: #10b981;
            font-weight: 500;
            font-family: 'Courier New', monospace;
            cursor: pointer;
            position: relative;
            text-decoration: underline dotted;
        }
        .recipient-group:hover {
            color: #059669;
        }
        
        /* Tooltip */
        .tooltip {
            position: absolute;
            background: #1a1f2e;
            border: 1px solid #4a90e2;
            border-radius: 8px;
            padding: 12px 16px;
            z-index: 1000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            min-width: 200px;
            max-width: 400px;
            display: none;
            pointer-events: none;
        }
        .tooltip.show {
            display: block;
        }
        .tooltip-title {
            font-size: 11px;
            color: #8b92a0;
            text-transform: uppercase;
            margin-bottom: 8px;
            letter-spacing: 0.5px;
            font-weight: 600;
        }
        .tooltip-list {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        .tooltip-list li {
            padding: 4px 0;
            color: #e4e6eb;
            font-size: 13px;
            font-family: 'Courier New', monospace;
        }
        .tooltip-list li:before {
            content: "• ";
            color: #4a90e2;
            margin-right: 6px;
        }
        .message-text {
            color: #e4e6eb;
            max-width: 500px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        .loading {
            text-align: center;
            padding: 60px 40px;
            color: #64748b;
            font-size: 14px;
        }
        .empty-state {
            text-align: center;
            padding: 60px 40px;
        }
        .empty-state-icon {
            font-size: 48px;
            margin-bottom: 12px;
            opacity: 0.2;
        }
        .empty-state-text {
            font-size: 14px;
            color: #8b92a0;
        }
        .result-count {
            font-size: 13px;
            color: #8b92a0;
            margin-bottom: 16px;
            padding: 0 24px;
        }
        .result-count strong {
            color: #ffffff;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <!-- Header -->
    <div class="header">
        <div class="header-left">
            <h1><i class="fas fa-shield-alt"></i> Cravex Admin Panel</h1>
        </div>
        <div class="header-right">
            <div class="user-info">
                <div class="user-avatar">A</div>
                <span class="user-name">Administrator</span>
            </div>
            <form action="/logout" method="POST" style="margin: 0;">
                <button type="submit" class="logout-btn"><i class="fas fa-sign-out-alt"></i> Çıkış</button>
            </form>
        </div>
    </div>
    
    <!-- Main Content -->
    <div class="container">
        <!-- Stats -->
        <div class="stats">
            <div class="stat-card">
                <div class="stat-label">TOPLAM MESAJ</div>
                <div class="stat-value" id="totalMessages">0</div>
                <div class="stat-icon"><i class="fas fa-comments"></i></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">TOPLAM ODA</div>
                <div class="stat-value" id="totalRooms">0</div>
                <div class="stat-icon"><i class="fas fa-door-open"></i></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">AKTİF KULLANICI</div>
                <div class="stat-value" id="totalUsers">0</div>
                <div class="stat-icon"><i class="fas fa-users"></i></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">ŞİFRESİZ</div>
                <div class="stat-value">100%</div>
                <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
            </div>
        </div>
        
        <!-- Filters -->
        <div class="filters-card">
            <div class="filters-header">
                <h2><i class="fas fa-filter"></i> Arama Filtreleri</h2>
            </div>
            
            <div class="filter-grid">
                <div class="filter-group">
                    <label>Oda ID</label>
                    <input type="text" id="filterRoomId" placeholder="!abc:localhost">
                </div>
                <div class="filter-group">
                    <label>Gönderen (Kullanıcı Adı)</label>
                    <input type="text" id="filterSender" placeholder="@kullanici:localhost">
                </div>
                <div class="filter-group">
                    <label>Mesaj İçeriğinde Ara</label>
                    <input type="text" id="searchQuery" placeholder="Kelime ara...">
                </div>
            </div>
            
            <div class="btn-group">
                <button class="btn-primary" onclick="searchMessages()">
                    <i class="fas fa-search"></i> Ara
                </button>
                <button class="btn-secondary" onclick="exportData('json')">
                    <i class="fas fa-download"></i> JSON
                </button>
                <button class="btn-secondary" onclick="exportData('csv')">
                    <i class="fas fa-file-csv"></i> CSV
                </button>
                <button class="btn-secondary" onclick="clearFilters()">
                    <i class="fas fa-redo"></i> Temizle
                </button>
            </div>
        </div>
        
        <!-- Messages -->
        <div class="messages-card">
            <div class="messages-header">
                <h2><i class="fas fa-list"></i> Mesajlar</h2>
                <div class="pagination" id="paginationTop" style="display: none;">
                    <button class="page-btn" onclick="previousPage()" id="prevBtnTop">
                        <i class="fas fa-chevron-left"></i> Önceki
                    </button>
                    <div class="pagination-info">
                        Sayfa <strong id="currentPageTop">1</strong> / <strong id="totalPagesTop">1</strong>
                    </div>
                    <button class="page-btn" onclick="nextPage()" id="nextBtnTop">
                        İleri <i class="fas fa-chevron-right"></i>
                    </button>
                </div>
            </div>
            <div class="messages-body">
                <div id="messagesContent">
                    <div class="empty-state">
                        <div class="empty-state-icon"><i class="fas fa-inbox"></i></div>
                        <div class="empty-state-text">Mesajları görüntülemek için filtreleri kullanın ve "Ara" butonuna tıklayın</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        let currentPage = 1;
        let totalPages = 1;
        let totalMessages = 0;
        const pageSize = 50;
        
        // Sayfa yüklenince stats'ı yükle
        loadStats();
        
        async function loadStats() {
            try {
                const response = await fetch('/api/stats');
                const stats = await response.json();
                
                document.getElementById('totalMessages').textContent = stats.total_messages.toLocaleString();
                document.getElementById('totalRooms').textContent = stats.total_rooms.toLocaleString();
                document.getElementById('totalUsers').textContent = stats.total_users.toLocaleString();
            } catch (error) {
                console.error('Stats yüklenirken hata:', error);
            }
        }
        
        function searchMessages() {
            currentPage = 1;
            loadMessages();
        }
        
        async function loadMessages() {
            const content = document.getElementById('messagesContent');
            content.innerHTML = '<div class="loading"><i class="fas fa-spinner fa-spin"></i> Mesajlar yükleniyor...</div>';
            
            const params = new URLSearchParams({
                room_id: document.getElementById('filterRoomId').value,
                sender: document.getElementById('filterSender').value,
                search: document.getElementById('searchQuery').value,
                page: currentPage,
                page_size: pageSize
            });
            
            try {
                const response = await fetch('/api/messages?' + params);
                const data = await response.json();
                
                if (data.error) {
                    content.innerHTML = '<div class="loading"><i class="fas fa-exclamation-circle"></i> Hata: ' + data.error + '</div>';
                    return;
                }
                
                totalMessages = data.total;
                totalPages = Math.ceil(totalMessages / pageSize);
                
                updatePagination();
                
                if (data.messages.length === 0) {
                    content.innerHTML = `
                        <div class="empty-state">
                            <div class="empty-state-icon"><i class="fas fa-search"></i></div>
                            <div class="empty-state-text">Arama kriterlerinize uygun mesaj bulunamadı</div>
                        </div>
                    `;
                    return;
                }
                
                const start = (currentPage - 1) * pageSize + 1;
                const end = Math.min(start + data.messages.length - 1, totalMessages);
                
                let html = `
                    <div class="result-count">
                        Toplam <strong>${totalMessages.toLocaleString()}</strong> mesajdan 
                        <strong>${start.toLocaleString()}</strong> - <strong>${end.toLocaleString()}</strong> arası gösteriliyor
                    </div>
                    <table>
                        <thead>
                            <tr>
                                <th style="width: 130px;">TARİH/SAAT</th>
                                <th style="width: 200px;">GÖNDEREN</th>
                                <th style="width: 150px;">GİTTİĞİ ODA</th>
                                <th style="width: 200px;">ALICI</th>
                                <th>MESAJ</th>
                            </tr>
                        </thead>
                        <tbody>
                `;
                
                data.messages.forEach(msg => {
                    let recipientCell = '';
                    if (msg.recipient_list && msg.recipient_list.length > 0) {
                        // Grup mesajı - tooltip ile göster
                        const recipientListJSON = JSON.stringify(msg.recipient_list).replace(/"/g, '&quot;');
                        recipientCell = `<span class="recipient-group" data-recipients='${recipientListJSON}'>${msg.recipient || 'Grup'}</span>`;
                    } else {
                        // Tekil alıcı
                        recipientCell = `<span class="recipient">${msg.recipient || 'Grup'}</span>`;
                    }
                    
                    html += `
                        <tr>
                            <td class="timestamp">${msg.timestamp}</td>
                            <td class="sender">${msg.sender}</td>
                            <td class="room-name">${msg.room_name || msg.room_id}</td>
                            <td>${recipientCell}</td>
                            <td class="message-text" title="${msg.message || ''}">${msg.message || '<em>Boş mesaj</em>'}</td>
                        </tr>
                    `;
                });
                
                html += '</tbody></table>';
                content.innerHTML = html;
                
            } catch (error) {
                content.innerHTML = '<div class="loading"><i class="fas fa-times-circle"></i> Bağlantı hatası: ' + error.message + '</div>';
            }
        }
        
        function updatePagination() {
            const paginationTop = document.getElementById('paginationTop');
            
            if (totalPages > 1) {
                paginationTop.style.display = 'flex';
                
                // Update page numbers
                document.getElementById('currentPageTop').textContent = currentPage;
                document.getElementById('totalPagesTop').textContent = totalPages;
                
                // Update button states
                document.getElementById('prevBtnTop').disabled = currentPage === 1;
                document.getElementById('nextBtnTop').disabled = currentPage === totalPages;
            } else {
                paginationTop.style.display = 'none';
            }
        }
        
        function nextPage() {
            if (currentPage < totalPages) {
                currentPage++;
                loadMessages();
                window.scrollTo(0, 0);
            }
        }
        
        function previousPage() {
            if (currentPage > 1) {
                currentPage--;
                loadMessages();
                window.scrollTo(0, 0);
            }
        }
        
        async function exportData(format) {
            const params = new URLSearchParams({
                room_id: document.getElementById('filterRoomId').value,
                sender: document.getElementById('filterSender').value,
                search: document.getElementById('searchQuery').value,
                format: format
            });
            
            window.location.href = '/api/export?' + params;
        }
        
        function clearFilters() {
            document.getElementById('filterRoomId').value = '';
            document.getElementById('filterSender').value = '';
            document.getElementById('searchQuery').value = '';
            
            currentPage = 1;
            totalPages = 1;
            
            document.getElementById('messagesContent').innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon"><i class="fas fa-inbox"></i></div>
                    <div class="empty-state-text">Mesajları görüntülemek için filtreleri kullanın ve "Ara" butonuna tıklayın</div>
                </div>
            `;
            
            document.getElementById('paginationTop').style.display = 'none';
        }
        
        // Enter tuşuyla arama
        document.querySelectorAll('input').forEach(input => {
            input.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    searchMessages();
                }
            });
        });
        
        // Tooltip functionality
        let tooltip = null;
        
        function createTooltip() {
            if (!tooltip) {
                tooltip = document.createElement('div');
                tooltip.className = 'tooltip';
                document.body.appendChild(tooltip);
            }
            return tooltip;
        }
        
        function showTooltip(element, recipients) {
            const tooltip = createTooltip();
            
            let html = '<div class="tooltip-title">Grup Üyeleri</div>';
            html += '<ul class="tooltip-list">';
            recipients.forEach(recipient => {
                html += `<li>${recipient}</li>`;
            });
            html += '</ul>';
            
            tooltip.innerHTML = html;
            tooltip.classList.add('show');
            
            // Position tooltip
            const rect = element.getBoundingClientRect();
            tooltip.style.position = 'fixed';
            tooltip.style.left = rect.left + 'px';
            tooltip.style.top = (rect.bottom + 5) + 'px';
        }
        
        function hideTooltip() {
            if (tooltip) {
                tooltip.classList.remove('show');
            }
        }
        
        // Event delegation for dynamically added elements
        document.addEventListener('mouseover', (e) => {
            if (e.target.classList.contains('recipient-group')) {
                try {
                    const recipients = JSON.parse(e.target.getAttribute('data-recipients'));
                    showTooltip(e.target, recipients);
                } catch (error) {
                    console.error('Error parsing recipients:', error);
                }
            }
        });
        
        document.addEventListener('mouseout', (e) => {
            if (e.target.classList.contains('recipient-group')) {
                hideTooltip();
            }
        });
    </script>
</body>
</html>
'''

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            session['logged_in'] = True
            session['username'] = username
            return redirect(url_for('index'))
        else:
            return render_template_string(LOGIN_TEMPLATE, error='Kullanıcı adı veya şifre hatalı!')
    
    return render_template_string(LOGIN_TEMPLATE)

@app.route('/logout', methods=['POST'])
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    return render_template_string(DASHBOARD_TEMPLATE)

@app.route('/api/stats')
@login_required
def get_stats():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
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
    except Exception as e:
        print(f"[HATA] /api/stats - {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/messages')
@login_required
def get_messages():
    try:
        room_id = request.args.get('room_id', '').strip()
        sender = request.args.get('sender', '').strip()
        search = request.args.get('search', '').strip()
        page = int(request.args.get('page', 1))
        page_size = int(request.args.get('page_size', 50))
        
        offset = (page - 1) * page_size
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        conditions = ["e.type = 'm.room.message'"]
        
        if room_id:
            conditions.append(cur.mogrify("e.room_id = %s", (room_id,)).decode('utf-8'))
        if sender:
            conditions.append(cur.mogrify("e.sender ILIKE %s", (f'%{sender}%',)).decode('utf-8'))
        if search:
            conditions.append(cur.mogrify("ej.json::json->'content'->>'body' ILIKE %s", (f'%{search}%',)).decode('utf-8'))
        
        where_clause = " AND ".join(conditions)
        
        # Toplam mesaj sayısını al
        count_query = f"""
            SELECT COUNT(*)
            FROM events e
            JOIN event_json ej ON e.event_id = ej.event_id
            WHERE {where_clause}
        """
        cur.execute(count_query)
        total = cur.fetchone()[0]
        
        # Sayfalı mesajları al
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
                ej.json::json->'content'->>'body' as message,
                (SELECT STRING_AGG(DISTINCT rm.user_id, ', ')
                 FROM room_memberships rm
                 WHERE rm.room_id = e.room_id
                   AND rm.user_id != e.sender
                   AND rm.membership = 'join') as recipients
            FROM events e
            JOIN event_json ej ON e.event_id = ej.event_id
            WHERE {where_clause}
            ORDER BY e.origin_server_ts DESC
            LIMIT {page_size} OFFSET {offset};
        """
        
        cur.execute(query)
        rows = cur.fetchall()
        
        messages = []
        for row in rows:
            recipients = row[5] if row[5] else ''
            # Eğer tek alıcı varsa direkt göster, birden fazlaysa sayı göster
            if recipients:
                recipient_list = recipients.split(', ')
                if len(recipient_list) == 1:
                    recipient_display = recipient_list[0]
                    recipient_full_list = None
                else:
                    recipient_display = f'Grup ({len(recipient_list)} kişi)'
                    recipient_full_list = recipient_list
            else:
                recipient_display = 'Grup'
                recipient_full_list = None
            
            messages.append({
                'timestamp': row[0].strftime('%Y-%m-%d %H:%M:%S') if row[0] else '',
                'sender': row[1],
                'room_id': row[2],
                'room_name': row[3] or 'İsimsiz oda',
                'message': row[4],
                'recipient': recipient_display,
                'recipient_list': recipient_full_list
            })
        
        cur.close()
        conn.close()
        
        return jsonify({
            'messages': messages,
            'total': total,
            'page': page,
            'page_size': page_size,
            'total_pages': (total + page_size - 1) // page_size
        })
    except Exception as e:
        print(f"[HATA] /api/messages - {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/export')
@login_required
def export_data():
    room_id = request.args.get('room_id', '').strip()
    sender = request.args.get('sender', '').strip()
    search = request.args.get('search', '').strip()
    format_type = request.args.get('format', 'json')
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        conditions = ["e.type = 'm.room.message'"]
        
        if room_id:
            conditions.append(cur.mogrify("e.room_id = %s", (room_id,)).decode('utf-8'))
        if sender:
            conditions.append(cur.mogrify("e.sender ILIKE %s", (f'%{sender}%',)).decode('utf-8'))
        if search:
            conditions.append(cur.mogrify("ej.json::json->'content'->>'body' ILIKE %s", (f'%{search}%',)).decode('utf-8'))
        
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
                ej.json::json->'content'->>'body' as message,
                (SELECT STRING_AGG(DISTINCT rm.user_id, ', ')
                 FROM room_memberships rm
                 WHERE rm.room_id = e.room_id
                   AND rm.user_id != e.sender
                   AND rm.membership = 'join') as recipients
            FROM events e
            JOIN event_json ej ON e.event_id = ej.event_id
            WHERE {where_clause}
            ORDER BY e.origin_server_ts ASC;
        """
        
        cur.execute(query)
        rows = cur.fetchall()
        
        messages = []
        for row in rows:
            recipients = row[5] if row[5] else 'Grup'
            # Eğer tek alıcı varsa direkt göster, birden fazlaysa sayı göster
            if recipients and recipients != 'Grup':
                recipient_list = recipients.split(', ')
                if len(recipient_list) == 1:
                    recipient_display = recipient_list[0]
                else:
                    recipient_display = f'Grup ({len(recipient_list)} kişi)'
            else:
                recipient_display = 'Grup'
            
            messages.append({
                'timestamp': row[0].strftime('%Y-%m-%d %H:%M:%S') if row[0] else '',
                'sender': row[1],
                'room_id': row[2],
                'room_name': row[3] or 'İsimsiz oda',
                'message': row[4],
                'recipient': recipient_display
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
                download_name=f'cravex_messages_{timestamp}.json'
            )
        
        elif format_type == 'csv':
            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=['timestamp', 'sender', 'room_name', 'recipient', 'message'])
            writer.writeheader()
            writer.writerows(messages)
            
            mem = io.BytesIO()
            mem.write(output.getvalue().encode('utf-8-sig'))
            mem.seek(0)
            
            return send_file(
                mem,
                mimetype='text/csv',
                as_attachment=True,
                download_name=f'cravex_messages_{timestamp}.csv'
            )
        
        return jsonify({'error': 'Invalid format'}), 400
        
    except Exception as e:
        print(f"[HATA] /api/export - {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("")
    print("=" * 60)
    print("  🛡️  CRAVEX ADMIN PANEL")
    print("=" * 60)
    print("")
    print("URL: http://localhost:9000")
    print("")
    print("📋 Giriş Bilgileri:")
    print("   Kullanıcı: admin")
    print("   Şifre: admin123")
    print("")
    print("✨ Özellikler:")
    print("   ✅ Güvenli login sistemi")
    print("   ✅ Minimal dark theme")
    print("   ✅ FontAwesome ikonlar")
    print("   ✅ Sayfalama (50 mesaj/sayfa)")
    print("   ✅ Gelişmiş filtreleme")
    print("   ✅ JSON/CSV export")
    print("")
    print("Durdurmak için: Ctrl+C")
    print("=" * 60)
    print("")
    
    app.run(host='0.0.0.0', port=9000, debug=False)
