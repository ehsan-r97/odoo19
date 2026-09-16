# 📘 Odoo 19 Full-Stack Installation Guide (Production-Grade)

## 🏗️ Architecture Overview

This guide sets up **Odoo 19** with a highly optimized, production-grade architecture on **Kubuntu / Ubuntu 24.04+ LTS**. It utilizes SCRAM-SHA-256 authentication, connection pooling, and multi-worker processing.

```text
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT (Browser)                         │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP (Port 80)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX (Reverse Proxy)                        │
│  • SSL Termination        • Static Asset Caching               │
│  • Gzip Compression       • WebSocket Routing (/websocket)      │
│  • Longpolling (/longpolling → Port 8072)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ Proxy (Port 8019)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ODOO 19 (Multi-Worker Mode)                    │
│  • 4 HTTP Workers + 2 Cron Threads + 1 Evented Worker          │
│  • Memory Limits (Soft: 2GB, Hard: 2.5GB)                      │
│  • Proxy Mode Enabled (Behind Nginx)                           │
└──────────┬─────────────────────────────────────┬────────────────┘
           │                                     │
           ▼                                     ▼
┌─────────────────────┐              ┌─────────────────────────┐
│   PGBOUNCER         │              │        REDIS            │
│   (Port 6432)       │              │      (Port 6379)        │
│   Connection Pool   │              │   Session Store (OCA)   │
│   SCRAM-SHA-256     │              │   ORM Cache             │
└──────────┬──────────┘              └─────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│              POSTGRESQL 16 (Port 5432)                          │
│  • SCRAM-SHA-256 Password Encryption                            │
│  • pgvector Extension (AI/RAG)                                  │
│  • Optimized Memory Settings                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites

| Component | Version | Purpose |
|-----------|---------|---------|
| OS | Kubuntu / Ubuntu 24.04+ LTS | Operating System |
| Python | 3.12 | Odoo Runtime |
| PostgreSQL | 16 | Database (with SCRAM-SHA-256) |
| pgvector | 0.8+ | AI/RAG Vector Search |
| PgBouncer | 1.22+ | Connection Pooling |
| Redis | 7+ | Session Management |
| Nginx | 1.24+ | Reverse Proxy & WebSockets |
| wkhtmltopdf | 0.12.6.1 (patched) | PDF Report Generation |

---

## 🔑 Credentials Reference

| Item | Value |
|------|-------|
| Ubuntu username | `odoo19` |
| Project directory | `/home/odoo19/odoo19` |
| PostgreSQL user | `odoo19` |
| PostgreSQL password | `999239` |
| Odoo Master Password | `999239` |
| Odoo internal port | `8019` |
| Longpolling port | `8072` |
| PgBouncer port | `6432` |
| Redis port | `6379` |
| Nginx port | `80` |

---

## 📦 Step-by-Step Installation

### Phase 1: System Preparation

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git wget curl rsync software-properties-common
```

### Phase 2: PostgreSQL 16 & SCRAM-SHA-256 Setup

Modern PgBouncer requires SCRAM-SHA-256 to authenticate securely with PostgreSQL 16.

```bash
# 1. Add the official PostgreSQL repository
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc

echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
    https://apt.postgresql.org/pub/repos/apt noble-pgdg main" | \
    sudo tee /etc/apt/sources.list.d/pgdg.list

# 2. Install PostgreSQL 16 with pgvector
sudo apt update
sudo apt install -y postgresql-16 postgresql-client-16 postgresql-16-pgvector

# 3. Enforce SCRAM-SHA-256 and create the Odoo user
sudo pg_ctlcluster 16 main start
sudo -u postgres psql -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256';"
sudo -u postgres psql -c "SELECT pg_reload_conf();"
sudo -u postgres psql -c "CREATE USER odoo19 WITH PASSWORD '999239' CREATEDB SUPERUSER;"

# 4. Enable the Vector extension for AI/RAG features
sudo -u postgres psql -d template1 -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

#### PostgreSQL Performance Configuration
```bash
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 2GB/" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#shared_buffers = 128MB/shared_buffers = 4GB/" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#work_mem = 4MB/work_mem = 128MB/" /etc/postgresql/16/main/postgresql.conf

echo "host    all             all             0.0.0.0/0               scram-sha-256" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
sudo pg_ctlcluster 16 main restart
```

### Phase 3: PgBouncer (Connection Pooling with SCRAM)

```bash
sudo apt install -y pgbouncer

# 1. Configure PgBouncer for SCRAM-SHA-256
sudo tee /etc/pgbouncer/pgbouncer.ini > /dev/null <<'EOF'
[databases]
* = host=127.0.0.1 port=5432

[pgbouncer]
listen_addr = 127.0.0.1
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = session
max_client_conn = 500
default_pool_size = 50
ignore_startup_parameters = extra_float_digits
EOF

# 2. Extract SCRAM secret from PostgreSQL and inject into PgBouncer
SCRAM_SECRET=$(sudo -u postgres psql -Atc "SELECT rolpassword FROM pg_authid WHERE rolname='odoo19';")
echo "\"odoo19\" \"${SCRAM_SECRET}\"" | sudo tee /etc/pgbouncer/userlist.txt

# 3. Set permissions and restart
sudo chown pgbouncer:pgbouncer /etc/pgbouncer/userlist.txt
sudo chmod 600 /etc/pgbouncer/userlist.txt
sudo systemctl restart pgbouncer
```

### Phase 4: Redis (Session Management)

```bash
sudo apt install -y redis-server
sudo systemctl enable --now redis-server
redis-cli ping # Should return PONG
```

### Phase 5: System Dependencies & wkhtmltopdf

```bash
sudo apt install -y \
    python3.12 python3.12-venv python3.12-dev python3-pip \
    libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev \
    libssl-dev libjpeg-dev libpq-dev libffi-dev \
    libfreetype-dev liblcms2-dev libtiff5-dev libwebp-dev \
    nodejs npm node-less xfonts-75dpi xfonts-base

wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo apt --fix-broken install -y
rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb
```

### Phase 6: Odoo User, Repository & Python Environment

```bash
sudo useradd -m -s /bin/bash odoo19
echo "odoo19:999239" | sudo chpasswd
sudo su - odoo19

git clone https://github.com/ehsan-r97/odoo19.git
cd odoo19

python3.12 -m venv venv
source venv/bin/activate

pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

# Install critical dependencies often missed on modern Kubuntu/Ubuntu
pip install "psycopg[binary]" psycopg2-binary PyYAML python-dotenv redis
pip install phonenumbers

exit
```

### Phase 7: Permissions & Directory Structure

```bash
sudo mkdir -p /home/odoo19/odoo19/{custom_addons,filestore,logs,backups}
sudo chown -R odoo19:odoo19 /home/odoo19/odoo19
sudo chmod 755 /home/odoo19/odoo19/custom_addons
```

### Phase 8: Nginx (Reverse Proxy & WebSockets)

Deploy the optimized Nginx configuration. This correctly routes standard traffic to port `8019` and WebSocket/Longpolling traffic to the Evented Service on port `8072`.

```bash
sudo apt install -y nginx

sudo tee /etc/nginx/sites-available/odoo19 > /dev/null <<'EOF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

upstream odoo {
    server 127.0.0.1:8019;
    keepalive 64;
}

upstream odoochat {
    server 127.0.0.1:8072;
    keepalive 64;
}

server {
    listen 80 default_server;
    server_name _;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    client_max_body_size 0;
    proxy_read_timeout 900s;
    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;

    gzip on;
    gzip_min_length 1100;
    gzip_buffers 4 32k;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
    gzip_vary on;

    location / {
        proxy_pass http://odoo;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    location /longpolling {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 2d;
        proxy_pass http://odoo;
        add_header Cache-Control "public, no-transform";
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/odoo19 /etc/nginx/sites-enabled/odoo19
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## 🚀 Starting Odoo

Since the `odoo.conf` file is maintained inside your repository, ensure it is present at `/home/odoo19/odoo19/odoo.conf` before starting.

### Option A: Manual Execution (Development / Tmux)
If you want to run Odoo manually without installing it as a background service, use `tmux` so it continues running if you close the terminal.

```bash
# Install tmux if not present
sudo apt install tmux -y

# Start a new tmux session
tmux new -s odoo19

# Switch to the odoo user and start the server
sudo su - odoo19
cd ~/odoo19
source venv/bin/activate
./odoo-bin -c odoo.conf

# To detach and leave it running in the background: Press Ctrl+B, then press D
# To reattach later: tmux attach -t odoo19
```

### Option B: Systemd Service (Production)
To run Odoo automatically in the background and have it start on server reboot.

**1. Create the service file:**
```bash
sudo tee /etc/systemd/system/odoo19.service > /dev/null <<'EOF'
[Unit]
Description=Odoo 19
After=network.target postgresql.service pgbouncer.service redis-server.service

[Service]
Type=simple
User=odoo19
Group=odoo19
WorkingDirectory=/home/odoo19/odoo19
ExecStart=/home/odoo19/odoo19/venv/bin/python3 /home/odoo19/odoo19/odoo-bin -c /home/odoo19/odoo19/odoo.conf
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

**2. Enable and start the service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now odoo19
sudo systemctl status odoo19 --no-pager
```

---

## 📄 Complete `odoo.conf` Reference

Below is the complete configuration reference. Unused parameters are commented out (`;`) but kept for documentation purposes so you can easily enable advanced features later.

```ini
[options]
; =============================================================================
;                         ODOO 19 MASTER CONFIGURATION
; =============================================================================

; -----------------------------------------------------------------------------
; 1. GENERAL & SERVER
; -----------------------------------------------------------------------------
http_interface = 127.0.0.1 ; Bind to localhost since Nginx handles external traffic
http_port = 8019
proxy_mode = True          ; CRITICAL: Must be True when behind Nginx
; https = False
; pidfile = /var/run/odoo/odoo.pid
server_wide_modules = base,web

; -----------------------------------------------------------------------------
; 2. DATABASE CONNECTION (Routing through PgBouncer on port 6432)
; -----------------------------------------------------------------------------
db_host = 127.0.0.1
db_port = 6432             ; Connects to PgBouncer, not direct Postgres (5432)
db_user = odoo19
db_password = 999239
db_maxconn = 64
db_sslmode = prefer
dbfilter = ^.*$
db_template = template0
unaccent = False

; -----------------------------------------------------------------------------
; 3. ADDONS PATHS & FILE STORAGE
; -----------------------------------------------------------------------------
addons_path = /home/odoo19/odoo19/odoo/addons,/home/odoo19/odoo19/custom_addons
data_dir = /home/odoo19/odoo19/filestore

; -----------------------------------------------------------------------------
; 4. SECURITY & MASTER PASSWORD
; -----------------------------------------------------------------------------
admin_passwd = 999239      ; Used for Database Manager operations
list_db = True

; -----------------------------------------------------------------------------
; 5. LOGGING & MONITORING
; -----------------------------------------------------------------------------
logfile = /home/odoo19/odoo19/logs/odoo.log
log_level = info
log_handler = :INFO
; log_rotate = 30          ; Handled by logrotate in production
; syslog = False

; -----------------------------------------------------------------------------
; 6. PERFORMANCE & WORKER PROCESSES
; -----------------------------------------------------------------------------
; Formula: (CPU cores * 2) + 1. Adjust based on your hardware.
workers = 4
max_cron_threads = 2
limit_memory_soft = 2147483648  ; 2GB
limit_memory_hard = 2684354560  ; 2.5GB
limit_time_cpu = 60
limit_time_real = 120
limit_request = 1073741824

; -----------------------------------------------------------------------------
; 7. CACHING & SESSIONS (Redis Integration)
; -----------------------------------------------------------------------------
; Note: Requires the OCA 'session_redis' module installed in your environment.
; If the module is not installed, Odoo will ignore these lines and use filestore.
; session_redis = True
; session_redis_host = 127.0.0.1
; session_redis_port = 6379
; session_redis_db = 1
; session_redis_password = False

; -----------------------------------------------------------------------------
; 8. REPORTING (PDF GENERATION)
; -----------------------------------------------------------------------------
; wkhtmltopdf_path = /usr/bin/wkhtmltopdf

; -----------------------------------------------------------------------------
; 9. EMAIL CONFIGURATION (SMTP)
; -----------------------------------------------------------------------------
; smtp_server = localhost
; smtp_port = 25
; smtp_ssl = False
; smtp_user = False
; smtp_password = False
; email_from = False

; -----------------------------------------------------------------------------
; 10. ADVANCED & MULTI-TENANCY
; -----------------------------------------------------------------------------
; osv_memory_age_limit = 1.0
; saas = False
; saas_port = 8069

; -----------------------------------------------------------------------------
; 11. DEVELOPER / DEBUG / TESTING OPTIONS
; -----------------------------------------------------------------------------
dev_mode = False
; test_enable = False
demo = False
translate_modules = ['all']
```

---

## 🔍 Verification Checklist

| Check | Command | Expected Result |
|-------|---------|-----------------|
| PostgreSQL running | `sudo pg_lsclusters` | `16 main 5432 online` |
| PgBouncer running | `sudo systemctl status pgbouncer` | `active (running)` |
| PgBouncer Auth | `PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d postgres -c "SELECT 1;"` | Returns `1` |
| Redis running | `redis-cli ping` | `PONG` |
| Nginx running | `sudo systemctl status nginx` | `active (running)` |
| Nginx Proxy | `curl -I http://127.0.0.1` | `HTTP/1.1 303 SEE OTHER` |
| Odoo Ports | `sudo ss -ltnp \| grep -E ':(80\|6432\|8019\|8072)\b'` | Shows Nginx, PgBouncer, and Python processes |
```
sudo -u odoo19 bash -lc '
cd ~/odoo19
source venv/bin/activate

echo "🔍 Searching for nested requirements.txt files..."

# Find all requirements.txt files inside custom_addons
find custom_addons -type f -name "requirements.txt" | while read -r req_file; do
    echo "---------------------------------------------------"
    echo "📦 Installing dependencies from: $req_file"
    echo "---------------------------------------------------"
    pip install -r "$req_file"
done

echo "✅ All nested requirements processed."
'
