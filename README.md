# 📘 Odoo 19 Full-Stack Installation Guide

## 🏗️ Architecture Overview

This guide sets up **Odoo 19** with a production-grade architecture on **Ubuntu 24.04 LTS** (compatible with WSL2 and Docker):

```
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
│  • 4 HTTP Workers + 2 Cron Threads                             │
│  • Memory Limits (Soft: 2GB, Hard: 2.5GB)                      │
│  • Redis Sessions (Port 6379)                                  │
│  • Proxy Mode Enabled                                          │
└──────────┬─────────────────────────────────────┬────────────────┘
           │                                     │
           ▼                                     ▼
┌─────────────────────┐              ┌─────────────────────────┐
│   PGBOUNCER         │              │        REDIS            │
│   (Port 6432)       │              │      (Port 6379)        │
│   Connection Pool   │              │   Session Store         │
│   Session Mode      │              │   ORM Cache             │
└──────────┬──────────┘              └─────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│              POSTGRESQL 16 (Port 5432)                          │
│  • pgvector Extension (AI/RAG)                                 │
│  • Optimized Memory Settings                                   │
│  • External Access Enabled                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites

| Component | Version | Purpose |
|-----------|---------|---------|
| Ubuntu | 24.04 LTS (Noble) | Operating System |
| Python | 3.12 | Odoo Runtime |
| PostgreSQL | 16 | Database |
| pgvector | 0.8+ | AI/RAG Vector Search |
| PgBouncer | 1.22+ | Connection Pooling |
| Redis | 7+ | Session Management |
| Nginx | 1.24+ | Reverse Proxy |
| Node.js | 18+ | Asset Compilation |
| wkhtmltopdf | 0.12.6.1 (patched) | PDF Report Generation |

---

## 🚫 What You Should NOT Do

| ❌ Do NOT | ✅ Do Instead |
|-----------|---------------|
| Run Odoo as `root` or with `sudo` | Use the dedicated `odoo19` system user |
| Use PostgreSQL 18 | Stick to PostgreSQL 16 for stability |
| Install `wkhtmltopdf` via `apt` | Use the patched `.deb` from GitHub releases |
| Expose PostgreSQL directly to the internet | Use PgBouncer and firewall rules |
| Use standard `git clone` for large repos | Use `--depth 1 --shallow-submodules` |
| Store passwords in plain text in scripts | Use environment variables or secure configs |
| Skip `pgvector` installation | Required for AI/RAG features in Odoo 19 |

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
| PgBouncer port | `6432` |
| Redis port | `6379` |
| Nginx port | `80` |
| Longpolling port | `8072` |
| GitHub repository | `https://github.com/ehsan-r97/odoo19.git` |

---

## 📦 Step-by-Step Installation

### Phase 1: System Preparation

```bash
# Update and upgrade system packages
sudo apt update && sudo apt upgrade -y

# Install core build tools
sudo apt install -y build-essential git wget curl rsync software-properties-common
```

#### Optional: Iranian APT Mirror (for restricted networks)

```bash
sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak

sudo tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null <<'EOF'
Types: deb deb-src
URIs: https://mirror.mobinhost.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb deb-src
URIs: https://mirror.mobinhost.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

sudo apt update
```

---

### Phase 2: PostgreSQL 16 & AI Readiness (pgvector)

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

# 3. Start PostgreSQL and create the Odoo user
sudo pg_ctlcluster 16 main start
sudo -u postgres psql -c "CREATE USER odoo19 WITH PASSWORD '999239' CREATEDB SUPERUSER;"

# 4. Enable the Vector extension for AI/RAG features
sudo -u postgres psql -d template1 -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

#### PostgreSQL Performance & External Access Configuration

```bash
# Configure memory settings for AI/Vector operations
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" \
    /etc/postgresql/16/main/postgresql.conf

sudo sed -i "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 2GB/" \
    /etc/postgresql/16/main/postgresql.conf

sudo sed -i "s/#shared_buffers = 128MB/shared_buffers = 4GB/" \
    /etc/postgresql/16/main/postgresql.conf

sudo sed -i "s/#work_mem = 4MB/work_mem = 128MB/" \
    /etc/postgresql/16/main/postgresql.conf

# Allow external connections (for DBeaver, pgAdmin, etc.)
echo "host    all             all             0.0.0.0/0               scram-sha-256" | \
    sudo tee -a /etc/postgresql/16/main/pg_hba.conf

# Allow PgBouncer to connect via MD5
sudo sed -i '/^local.*all.*postgres.*peer/i host    all             all             127.0.0.1/32            md5' \
    /etc/postgresql/16/main/pg_hba.conf

# Restart PostgreSQL
sudo pg_ctlcluster 16 main restart
```

---

### Phase 3: PgBouncer (Connection Pooling)

```bash
# 1. Install PgBouncer
sudo apt install -y pgbouncer

# 2. Configure PgBouncer
sudo tee /etc/pgbouncer/pgbouncer.ini > /dev/null <<'EOF'
[databases]
* = host=127.0.0.1 port=5432

[pgbouncer]
listen_port = 6432
listen_addr = 127.0.0.1
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = session
max_client_conn = 500
default_pool_size = 50
ignore_startup_parameters = extra_float_digits
EOF

# 3. Generate the secure password hash
echo '"odoo19" "md5'$(echo -n '999239odoo19' | md5sum | cut -d' ' -f1)'"' | \
    sudo tee /etc/pgbouncer/userlist.txt

# 4. Set permissions
sudo chown postgres:postgres /etc/pgbouncer/userlist.txt
sudo chmod 600 /etc/pgbouncer/userlist.txt

# 5. Restart PgBouncer
sudo service pgbouncer restart
```

---

### Phase 4: Redis (Session Management)

```bash
# Install Redis
sudo apt install -y redis-server

# Start and enable Redis
sudo service redis-server start
sudo systemctl enable redis-server

# Verify Redis is running
redis-cli ping
# Should return: PONG
```

---

### Phase 5: System Dependencies & wkhtmltopdf

```bash
# 1. Install Python 3.12 and all C-libraries
sudo apt install -y \
    python3.12 python3.12-venv python3.12-dev python3-pip \
    libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev \
    libssl-dev libjpeg-dev libpq-dev libffi-dev \
    libfreetype-dev liblcms2-dev libtiff5-dev libwebp-dev \
    nodejs npm node-less xfonts-75dpi xfonts-base

# 2. Download and install the patched wkhtmltopdf
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo apt --fix-broken install -y
rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb

# 3. Verify wkhtmltopdf installation
wkhtmltopdf --version
# Should output: wkhtmltopdf 0.12.6.1 (with patched qt)
```

---

### Phase 6: Odoo User, Repository & Python Environment

```bash
# 1. Create the dedicated system user
sudo useradd -m -s /bin/bash odoo19
echo "odoo19:999239" | sudo chpasswd

# 2. Switch to the odoo19 user
sudo su - odoo19

# 3. Configure Git for SSH and submodules
mkdir -p ~/.ssh
cat << 'EOF' > ~/.ssh/config
Host github.com
    ServerAliveInterval 60
    ServerAliveCountMax 30
EOF
chmod 600 ~/.ssh/config

# Force Git to use SSH for all GitHub URLs (required for submodules)
git config --global url."git@github.com:".insteadOf "https://github.com/"

# 4. Clone the repository with submodules (Blobless to prevent timeouts)
git clone --filter=blob:none --depth 1 --shallow-submodules \
    git@github.com:ehsan-r97/odoo19.git

cd odoo19

# 5. Create and activate the Python virtual environment
python3.12 -m venv venv
source venv/bin/activate

# 6. Install Python dependencies
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
pip install phonenumbers

# 7. Exit back to your main admin user
exit
```

---

### Phase 7: Configuration & Permissions

```bash
# 1. Ensure directories exist
sudo mkdir -p /home/odoo19/odoo19/{custom_addons,filestore,logs,backups}

# 2. Transfer ownership to the odoo19 user
sudo chown -R odoo19:odoo19 /home/odoo19/odoo19

# 3. Secure the configuration file
sudo chmod 600 /home/odoo19/odoo19/odoo.conf

# 4. Make scripts executable
sudo chmod +x /home/odoo19/odoo19/start_odoo.sh
sudo chmod +x /home/odoo19/odoo19/odoo-bin
```

---

### Phase 8: Nginx (Reverse Proxy)

```bash
# 1. Install Nginx
sudo apt install -y nginx

# 2. Deploy the optimized configuration
sudo tee /etc/nginx/sites-available/odoo19 > /dev/null <<'EOF'
upstream odoo {
    server 127.0.0.1:8019;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

server {
    listen 80;
    server_name _;

    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    
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
    }

    location /longpolling {
        proxy_pass http://odoochat;
    }
    
    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 2d;
        proxy_pass http://odoo;
        add_header Cache-Control "public, no-transform";
    }
}
EOF

# 3. Enable the site and restart Nginx
sudo ln -s /etc/nginx/sites-available/odoo19 /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## 🚀 Final Launch

```bash
# 1. Start all background services
sudo pg_ctlcluster 16 main start
sudo service pgbouncer start
sudo service redis-server start
sudo service nginx start

# 2. Switch to the odoo19 user and launch Odoo
sudo su - odoo19
cd ~/odoo19
./start_odoo.sh
```

Wait for the terminal to output:
```
HTTP service (werkzeug) running on 0.0.0.0:8019
```

### Access Odoo

| Method | URL |
|--------|-----|
| Via Nginx (Recommended) | `http://localhost` |
| Direct (Bypassing Nginx) | `http://localhost:8019` |

### Database Creation Form

| Field | Value |
|-------|-------|
| Master Password | `999239` |
| Database Name | Any name |
| Email | `admin@example.com` |
| Password | `admin` |

---

## 📄 Complete `odoo.conf` Reference

This is the full configuration file with **all available parameters**. Unused parameters are commented out for reference.

```ini
[options]
; =============================================================================
;                         ODOO 19 MASTER CONFIGURATION
; =============================================================================
; Optimized for: User 'odoo19', Ubuntu 24.04, PostgreSQL 16, PgBouncer, Redis
; =============================================================================

; -----------------------------------------------------------------------------
; 1. GENERAL & SERVER
; -----------------------------------------------------------------------------
http_enable = True
http_interface = 0.0.0.0
http_port = 8019
https = False
; CRITICAL: Must be True when behind Nginx
proxy_mode = True
; pidfile = /var/run/odoo/odoo.pid
; pg_path = False
server_wide_modules = base,web

; -----------------------------------------------------------------------------
; 2. DATABASE CONNECTION (Routing through PgBouncer on port 6432)
; -----------------------------------------------------------------------------
db_host = 127.0.0.1
db_port = 6432
db_user = odoo19
db_password = 999239
db_name = False
db_maxconn = 64
db_sslmode = prefer
dbfilter = ^.*$
db_template = template0
unaccent = False
; log_db = False
; log_db_level = warning

; -----------------------------------------------------------------------------
; 3. ADDONS PATHS & FILE STORAGE
; -----------------------------------------------------------------------------
addons_path = /home/odoo19/odoo19/odoo/addons,/home/odoo19/odoo19/custom_addons
data_dir = /home/odoo19/odoo19/filestore

; -----------------------------------------------------------------------------
; 4. SECURITY & MASTER PASSWORD
; -----------------------------------------------------------------------------
admin_passwd = 999239
; csv_internal_sep = ,
list_db = True

; -----------------------------------------------------------------------------
; 5. LOGGING & MONITORING
; -----------------------------------------------------------------------------
logfile = /home/odoo19/odoo19/logs/odoo.log
log_level = info
log_handler = :INFO
log_rotate = 30
; syslog = False

; -----------------------------------------------------------------------------
; 6. PERFORMANCE & WORKER PROCESSES
; -----------------------------------------------------------------------------
; Formula: (CPU cores * 2) + 1. Adjust based on your hardware.
workers = 4
max_cron_threads = 2
limit_memory_soft = 2147483648
limit_memory_hard = 2684354560
limit_time_cpu = 60
limit_time_real = 120
limit_request = 1073741824
longpolling_port = 8072

; -----------------------------------------------------------------------------
; 7. CACHING & SESSIONS (Redis Integration)
; -----------------------------------------------------------------------------
session_redis = True
session_redis_host = 127.0.0.1
session_redis_port = 6379
session_redis_db = 1
session_redis_password = False
; session_redis_sentinel = False
; session_redis_sentinel_master = False
; cache = True
; cache_size = 10000

; -----------------------------------------------------------------------------
; 8. EMAIL CONFIGURATION (SMTP)
; -----------------------------------------------------------------------------
; smtp_server = localhost
; smtp_port = 25
; smtp_ssl = False
; smtp_user = False
; smtp_password = False
; email_from = False

; -----------------------------------------------------------------------------
; 9. REPORTING (PDF GENERATION)
; -----------------------------------------------------------------------------
wkhtmltopdf_path = /usr/bin/wkhtmltopdf
; reportgz = True

; -----------------------------------------------------------------------------
; 10. ADVANCED & MULTI-TENANCY
; -----------------------------------------------------------------------------
osv_memory_age_limit = 1.0
; osv_memory_count_limit = False
; saas = False
; saas_account = False
; saas_port = 8069

; -----------------------------------------------------------------------------
; 11. SECURITY (HTTPS / HSTS)
; -----------------------------------------------------------------------------
; hsts = False
; hsts_max_age = 31536000
; hsts_include_subdomains = False

; -----------------------------------------------------------------------------
; 12. DEVELOPER / DEBUG / TESTING OPTIONS
; -----------------------------------------------------------------------------
dev_mode = False
; test_enable = False
; test_file = False
; test_tags = False
demo = False
; without_demo = False
translate_modules = ['all']
; ignore_addons = []

; -----------------------------------------------------------------------------
; 13. GEOIP
; -----------------------------------------------------------------------------
; geoip_database = /usr/share/GeoIP/GeoLite2-City.mmdb

; -----------------------------------------------------------------------------
; 14. MISCELLANEOUS
; -----------------------------------------------------------------------------
; env_file = False
; timezone = False
```

---

## 🔧 Service Management

### Start All Services

```bash
sudo pg_ctlcluster 16 main start
sudo service pgbouncer start
sudo service redis-server start
sudo service nginx start

sudo su - odoo19
cd ~/odoo19
./start_odoo.sh
```

### Stop Odoo

Press `Ctrl+C` in the terminal where Odoo is running.

### Check Service Status

```bash
sudo pg_lsclusters
sudo service pgbouncer status
sudo service redis-server status
sudo service nginx status
```

---

## 🔍 Verification Checklist

| Check | Command | Expected Result |
|-------|---------|-----------------|
| PostgreSQL running | `sudo pg_lsclusters` | `16 main 5432 online` |
| PgBouncer running | `sudo service pgbouncer status` | `active (running)` |
| Redis running | `redis-cli ping` | `PONG` |
| Nginx running | `sudo service nginx status` | `active (running)` |
| Odoo accessible | `curl -I http://localhost:8019` | `HTTP/1.1 200 OK` |
| wkhtmltopdf works | `wkhtmltopdf --version` | `0.12.6.1 (with patched qt)` |
| pgvector enabled | `sudo -u postgres psql -d template1 -c "SELECT * FROM pg_extension WHERE extname='vector';"` | Returns a row |
| External DB access | Connect via DBeaver using WSL IP, port 5432 | Successful connection |

### Find Your WSL IP Address

```bash
hostname -I | awk '{print $1}'
```

Use this IP with port `5432`, username `odoo19`, and password `999239` in your SQL management tool.

---

## 🐛 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| `fatal: early EOF` during git clone | Use `--depth 1 --shallow-submodules` flags |
| `psycopg2` build failure | Install `libpq-dev`: `sudo apt install -y libpq-dev` |
| `python-ldap` build failure | Install LDAP headers: `sudo apt install -y libldap2-dev libsasl2-dev` |
| `wkhtmltopdf` not found | Install the patched `.deb` from GitHub releases |
| `pgbouncer` auth failure | Regenerate MD5 hash in `userlist.txt` |
| Redis connection refused | Check `sudo service redis-server status` |
| Odoo won't start | Check logs: `tail -f /home/odoo19/odoo19/logs/odoo.log` |
| Nginx 502 Bad Gateway | Ensure Odoo is running on port 8019 |

### View Odoo Logs

```bash
tail -f /home/odoo19/odoo19/logs/odoo.log
```

### Restart Everything

```bash
# Stop Odoo (Ctrl+C in terminal)
sudo pg_ctlcluster 16 main restart
sudo service pgbouncer restart
sudo service redis-server restart
sudo service nginx restart

# Start Odoo again
sudo su - odoo19
cd ~/odoo19
./start_odoo.sh
```

---

## 📈 Performance Optimizations Summary

| Layer | Optimization | Status |
|-------|-------------|--------|
| Odoo | Multi-worker mode (4 workers + 2 cron) | ✅ |
| Odoo | Memory limits (2GB soft, 2.5GB hard) | ✅ |
| Odoo | Request timeouts (60s CPU, 120s real) | ✅ |
| Database | Connection pooling via PgBouncer | ✅ |
| Database | Optimized memory settings (4GB shared_buffers) | ✅ |
| Database | pgvector for AI/RAG | ✅ |
| Cache | Redis for session storage | ✅ |
| Proxy | Nginx with gzip compression | ✅ |
| Proxy | Static asset caching (2 days) | ✅ |
| Proxy | WebSocket routing for live chat | ✅ |
| Reports | Patched wkhtmltopdf for PDF generation | ✅ |

---

## 🤖 AI/RAG Features (Odoo 19)

This installation includes the `pgvector` extension, enabling:

- **Vector Search**: Semantic search across documents
- **RAG (Retrieval-Augmented Generation)**: AI-powered document Q&A
- **Knowledge Base**: Intelligent document indexing

### Enable AI in Odoo

1. Navigate to **Settings → General Settings**
2. Find the **AI Configuration** section
3. Configure your LLM provider (OpenAI, Azure, Ollama, etc.)
4. Install the **Knowledge** module from Apps
5. Upload documents to begin AI indexing

---

## 🔄 WSL2-Specific Notes

- Services do **not** start automatically after a WSL2 reboot
- Use the "Start All Services" commands after each reboot
- To stop Odoo, press `Ctrl+C` in its terminal
- Never run Odoo with `sudo`
- If using Docker, replace `service` commands with `supervisord` or container orchestration

---

## 📝 License

This project is proprietary software. All rights reserved.

---

## 👨‍💻 Author

**Ehsan REZAEI**
- GitHub: [@ehsan-r97](https://github.com/ehsan-r97)
- Repository: [odoo19](https://github.com/ehsan-r97/odoo19)

---

## 📚 Additional Resources

- [Odoo Documentation](https://www.odoo.com/documentation)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PgBouncer Documentation](https://www.pgbouncer.org/)
- [Redis Documentation](https://redis.io/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [pgvector GitHub](https://github.com/pgvector/pgvector)
