# Odoo 19 Full-Stack Installation, Performance, Persian RTL, AI/PostgreSQL, and Addon Development Guide

This repository provides a complete fixed deployment and development environment for **Odoo 19** on **Kubuntu 26 / Ubuntu LTS**.

The setup is intended for:

- Odoo 19 production-style installation.
- Odoo addon development.
- Multiple independent Git-based addon folders.
- High-performance PostgreSQL usage.
- PgBouncer connection pooling.
- Redis cache/session support.
- Nginx reverse proxy.
- WebSocket and longpolling support.
- Persian `fa_IR` RTL interface support.
- Persian PDF report rendering.
- PostgreSQL AI/vector capabilities using `pgvector`.
- Fixed configuration values, without parameterized templates.

This guide uses only **English** and **Persian**. Arabic is not included.

---

## Table of Contents

1. [Fixed Deployment Profile](#1-fixed-deployment-profile)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Phase 1: System Preparation](#4-phase-1-system-preparation)
5. [Phase 2: Persian Locale and Font Preparation](#5-phase-2-persian-locale-and-font-preparation)
6. [Phase 3: Operating System Performance Tuning](#6-phase-3-operating-system-performance-tuning)
7. [Phase 4: PostgreSQL 16 Installation and Performance Tuning](#7-phase-4-postgresql-16-installation-and-performance-tuning)
8. [Phase 5: PostgreSQL AI/Vector Extensions](#8-phase-5-postgresql-aivector-extensions)
9. [Phase 6: PgBouncer Connection Pooling](#9-phase-6-pgbouncer-connection-pooling)
10. [Phase 7: Redis Performance Cache](#10-phase-7-redis-performance-cache)
11. [Phase 8: Node.js, npm, RTL CSS, and Persian Font Support](#11-phase-8-nodejs-npm-rtl-css-and-persian-font-support)
12. [Phase 9: Patched wkhtmltopdf for Persian PDF Reports](#12-phase-9-patched-wkhtmltopdf-for-persian-pdf-reports)
13. [Phase 10: Python 3.12 and Odoo System Dependencies](#13-phase-10-python-312-and-odoo-system-dependencies)
14. [Phase 11: Odoo System User and Repository Deployment](#14-phase-11-odoo-system-user-and-repository-deployment)
15. [Phase 12: Python Virtual Environment and Addon Requirements](#15-phase-12-python-virtual-environment-and-addon-requirements)
16. [Phase 13: Fixed Odoo Configuration File](#16-phase-13-fixed-odoo-configuration-file)
17. [Phase 14: Nginx Reverse Proxy, WebSocket, and Longpolling](#17-phase-14-nginx-reverse-proxy-websocket-and-longpolling)
18. [Phase 15: Odoo systemd Service](#18-phase-15-odoo-systemd-service)
19. [Phase 16: Database Initialization and Persian Language Loading](#19-phase-16-database-initialization-and-persian-language-loading)
20. [Phase 17: Start and Verify Odoo](#20-phase-17-start-and-verify-odoo)
21. [Persian RTL Support in Odoo 19](#21-persian-rtl-support-in-odoo-19)
22. [PostgreSQL AI and Vector Search Support](#22-postgresql-ai-and-vector-search-support)
23. [Sub Git Addon Folder Management](#23-sub-git-addon-folder-management)
24. [Odoo Addon Development Workflow](#24-odoo-addon-development-workflow)
25. [Persian Translation Workflow for Custom Addons](#25-persian-translation-workflow-for-custom-addons)
26. [Performance Monitoring](#26-performance-monitoring)
27. [Backup and Restore](#27-backup-and-restore)
28. [Log Rotation](#28-log-rotation)
29. [Troubleshooting](#29-troubleshooting)
30. [Final Verification Checklist](#30-final-verification-checklist)

---

## 1. Fixed Deployment Profile

This guide uses fixed values. Do not replace them unless you intentionally rebuild the entire environment.

### 1.1 Target Operating System

| Item | Value |
|---|---|
| OS | Kubuntu 26 / Ubuntu LTS |
| Architecture | x86_64 |
| Recommended minimum RAM | 16 GB |
| Recommended minimum CPU | 8 vCPU |
| Recommended disk | 100 GB NVMe/SSD |

### 1.2 Fixed Paths

| Item | Path |
|---|---|
| Odoo Linux user | `odoo19` |
| Odoo home directory | `/home/odoo19` |
| Odoo project directory | `/home/odoo19/odoo19` |
| Custom addons directory | `/home/odoo19/odoo19/custom_addons` |
| Filestore directory | `/home/odoo19/odoo19/filestore` |
| Logs directory | `/home/odoo19/odoo19/logs` |
| Backups directory | `/home/odoo19/odoo19/backups` |
| Python virtual environment | `/home/odoo19/odoo19/venv` |
| Odoo configuration file | `/home/odoo19/odoo19/odoo.conf` |

### 1.3 Fixed Ports

| Service | Port |
|---|---:|
| Nginx public HTTP | 80 |
| Odoo internal HTTP | 8019 |
| Odoo evented/WebSocket/longpolling | 8072 |
| PgBouncer | 6432 |
| PostgreSQL | 5432 |
| Redis | 6379 |

### 1.4 Fixed Credentials

These credentials are fixed for your current convenience.

| Item | Value |
|---|---|
| Linux user | `odoo19` |
| Linux password | `999239` |
| PostgreSQL user | `odoo19` |
| PostgreSQL password | `999239` |
| Odoo master password | `999239` |
| Default Odoo database name | `odoo19` |
| Default Odoo admin login | `admin` |

> Note: You stated that you do not want to change passwords currently. These fixed passwords are therefore preserved throughout this document.

---

## 2. Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT BROWSER                           │
│                    English / Persian UI                         │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP Port 80
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                          NGINX                                  │
│                                                                 │
│  • Reverse proxy                                                │
│  • Static asset caching                                         │
│  • Gzip compression                                             │
│  • WebSocket routing: /websocket                                │
│  • Longpolling routing: /longpolling                            │
│  • Proxy to Odoo HTTP port 8019                                 │
│  • Proxy to Odoo evented port 8072                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ODOO 19                                   │
│                                                                 │
│  • Multi-worker mode                                            │
│  • 4 HTTP workers                                               │
│  • 2 cron threads                                               │
│  • Evented worker for WebSocket/longpolling                     │
│  • Proxy mode enabled                                           │
│  • Persian RTL support                                          │
│  • Custom addon development support                             │
└───────────────┬─────────────────────────────────┬───────────────┘
                │                                 │
                ▼                                 ▼
┌───────────────────────────┐       ┌─────────────────────────────┐
│        PGBOUNCER          │       │           REDIS             │
│                           │       │                             │
│  • Connection pooling     │       │  • Cache                    │
│  • Port 6432              │       │  • Session support          │
│  • SCRAM-SHA-256          │       │  • Port 6379                │
└─────────────┬─────────────┘       └─────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     POSTGRESQL 16                               │
│                                                                 │
│  • Port 5432                                                    │
│  • SCRAM-SHA-256 authentication                                 │
│  • pgvector for AI/vector search                                │
│  • pg_trgm for fuzzy text search                                │
│  • unaccent for Persian/Latin search behavior                   │
│  • pg_stat_statements for query performance analysis            │
│  • Optimized memory and WAL settings                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Prerequisites

Before starting, ensure:

- You have root or sudo access.
- The server has at least 16 GB RAM and 8 vCPU for the fixed performance profile.
- Ports 80, 8019, 8072, 6432, 5432, and 6379 are handled correctly.
- PostgreSQL, PgBouncer, Redis, Nginx, and Odoo are installed on the same server.
- Your repository contains Odoo 19 source code and custom addon folders.

---

## 4. Phase 1: System Preparation

Update the system and install base tools.

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
    build-essential \
    git \
    wget \
    curl \
    rsync \
    unzip \
    jq \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    locales \
    fontconfig
```

---

## 5. Phase 2: Persian Locale and Font Preparation

Install UTF-8 locales for English and Persian.

```bash
for loc in en_US.UTF-8 fa_IR.UTF-8; do
    if ! grep -q "^${loc}" /etc/locale.gen; then
        echo "${loc} UTF-8" | sudo tee -a /etc/locale.gen > /dev/null
    fi
    sudo sed -i "s|^# *${loc}|${loc}|" /etc/locale.gen
done

sudo locale-gen
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
```

Install basic font support.

```bash
sudo apt install -y \
    fontconfig \
    fonts-dejavu-core
```

---

## 6. Phase 3: Operating System Performance Tuning

Apply fixed kernel performance settings.

```bash
sudo tee /etc/sysctl.d/99-odoo19-performance.conf > /dev/null <<'EOF'
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

fs.file-max = 1000000

net.core.somaxconn = 4096
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
EOF

sudo sysctl --system
```

Apply file descriptor limits for the Odoo user.

```bash
sudo tee /etc/security/limits.d/99-odoo19.conf > /dev/null <<'EOF'
odoo19 soft nofile 65536
odoo19 hard nofile 65536
odoo19 soft nproc 4096
odoo19 hard nproc 4096
EOF
```

---

## 7. Phase 4: PostgreSQL 16 Installation and Performance Tuning

### 7.1 Add the Official PostgreSQL Repository

This detects the Kubuntu/Ubuntu codename automatically and falls back to `noble-pgdg` if required.

```bash
CODENAME="$(lsb_release -cs)"

sudo install -d /usr/share/postgresql-common/pgdg

sudo curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc

echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${CODENAME}-pgdg main" | \
    sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null

if ! sudo apt-get update; then
    echo "PostgreSQL repository for ${CODENAME}-pgdg is unavailable. Trying noble-pgdg..."
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt noble-pgdg main" | \
        sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null
    sudo apt-get update
fi
```

### 7.2 Install PostgreSQL 16

```bash
sudo apt install -y \
    postgresql-16 \
    postgresql-client-16
```

### 7.3 Fixed PostgreSQL Performance Configuration

Create the configuration drop-in directory.

```bash
sudo mkdir -p /etc/postgresql/16/main/conf.d
```

Ensure PostgreSQL loads `conf.d`.

```bash
sudo sed -i "s|^#include_dir = 'conf.d'|include_dir = 'conf.d'|" \
    /etc/postgresql/16/main/postgresql.conf

grep -q "^include_dir = 'conf.d'" /etc/postgresql/16/main/postgresql.conf || \
    echo "include_dir = 'conf.d'" | \
    sudo tee -a /etc/postgresql/16/main/postgresql.conf > /dev/null
```

Write the fixed performance configuration.

```bash
sudo tee /etc/postgresql/16/main/conf.d/99-odoo19-performance.conf > /dev/null <<'EOF'
listen_addresses = 'localhost'

max_connections = 200
superuser_reserved_connections = 5

shared_buffers = 4GB
effective_cache_size = 10GB
maintenance_work_mem = 1GB
work_mem = 32MB
temp_buffers = 32MB

wal_buffers = 64MB
checkpoint_completion_target = 0.9

random_page_cost = 1.1
effective_io_concurrency = 200

default_statistics_target = 100
huge_pages = try

password_encryption = scram-sha-256

shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all

log_min_duration_statement = 500ms
log_checkpoints = on
log_lock_waits = on
log_temp_files = 0

lc_messages = 'en_US.UTF-8'
EOF
```

### 7.4 Configure PostgreSQL Authentication

Ensure SCRAM-SHA-256 authentication is allowed for local TCP connections.

```bash
grep -q "^host    all             all             127.0.0.1/32            scram-sha-256" /etc/postgresql/16/main/pg_hba.conf || \
echo "host    all             all             127.0.0.1/32            scram-sha-256" | \
    sudo tee -a /etc/postgresql/16/main/pg_hba.conf > /dev/null

grep -q "^host    all             all             ::1/128                 scram-sha-256" /etc/postgresql/16/main/pg_hba.conf || \
echo "host    all             all             ::1/128                 scram-sha-256" | \
    sudo tee -a /etc/postgresql/16/main/pg_hba.conf > /dev/null
```

Restart PostgreSQL.

```bash
sudo pg_ctlcluster 16 main restart || sudo systemctl restart postgresql
sudo systemctl enable postgresql || true
```

### 7.5 Create the Fixed Odoo PostgreSQL User

```bash
sudo -u postgres psql -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256';"
sudo -u postgres psql -c "SELECT pg_reload_conf();"

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='odoo19'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER odoo19 WITH PASSWORD '999239' CREATEDB SUPERUSER;"

sudo -u postgres psql -c "ALTER USER odoo19 WITH PASSWORD '999239' CREATEDB SUPERUSER;"
```

---

## 8. Phase 5: PostgreSQL AI/Vector Extensions

Install PostgreSQL extensions required for AI, vector search, fuzzy search, Persian/Latin search behavior, and performance analysis.

### 8.1 Install pgvector

Try the packaged version first.

```bash
sudo apt install -y postgresql-16-pgvector
```

If the package is unavailable, compile `pgvector` from source.

```bash
if ! dpkg -s postgresql-16-pgvector >/dev/null 2>&1; then
    sudo apt install -y postgresql-server-dev-16 build-essential git

    rm -rf /tmp/pgvector
    git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git /tmp/pgvector

    make -C /tmp/pgvector
    sudo make -C /tmp/pgvector install
fi
```

### 8.2 Enable Extensions in template1

Extensions enabled in `template1` are inherited by newly created Odoo databases.

```bash
for ext in vector pg_trgm unaccent pg_stat_statements; do
    sudo -u postgres psql -d template1 -c "CREATE EXTENSION IF NOT EXISTS ${ext};"
done
```

---

## 9. Phase 6: PgBouncer Connection Pooling

Install PgBouncer.

```bash
sudo apt install -y pgbouncer
```

Write the fixed PgBouncer configuration.

```bash
sudo tee /etc/pgbouncer/pgbouncer.ini > /dev/null <<'EOF'
[databases]
* = host=127.0.0.1 port=5432

[pgbouncer]
listen_addr = 127.0.0.1
listen_port = 6432

auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

admin_users = odoo19
stats_users = odoo19

pool_mode = session

max_client_conn = 500
default_pool_size = 80
min_pool_size = 10

reserve_pool_size = 10
reserve_pool_timeout = 3

server_idle_timeout = 600
server_lifetime = 3600
server_login_retry = 3

query_wait_timeout = 120
client_login_timeout = 60

tcp_keepalive = 1
tcp_keepcnt = 3
tcp_keepidle = 30
tcp_keepintvl = 10

ignore_startup_parameters = extra_float_digits
EOF
```

Extract the PostgreSQL SCRAM secret and place it into PgBouncer.

```bash
SCRAM_SECRET=$(sudo -u postgres psql -Atc "SELECT rolpassword FROM pg_authid WHERE rolname='odoo19';")

printf '"odoo19" "%s"\n' "$SCRAM_SECRET" | \
    sudo tee /etc/pgbouncer/userlist.txt > /dev/null

sudo chown pgbouncer:pgbouncer /etc/pgbouncer/userlist.txt
sudo chmod 600 /etc/pgbouncer/userlist.txt
```

Enable and restart PgBouncer.

```bash
sudo systemctl enable --now pgbouncer
sudo systemctl restart pgbouncer
```

Test PgBouncer authentication.

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d postgres -c "SELECT 1;"
```

Expected result:

```text
 ?column?
----------
        1
```

---

## 10. Phase 7: Redis Performance Cache

Install Redis.

```bash
sudo apt install -y redis-server
```

Append fixed Redis performance settings if they are not already present.

```bash
grep -q "^maxmemory 1073741824" /etc/redis/redis.conf || \
sudo tee -a /etc/redis/redis.conf > /dev/null <<'EOF'

# Odoo 19 fixed Redis performance settings
maxmemory 1073741824
maxmemory-policy allkeys-lru
appendonly no
save ""
timeout 0
tcp-keepalive 300
EOF
```

Enable and restart Redis.

```bash
sudo systemctl enable --now redis-server
sudo systemctl restart redis-server
```

Test Redis.

```bash
redis-cli ping
```

Expected result:

```text
PONG
```

---

## 11. Phase 8: Node.js, npm, RTL CSS, and Persian Font Support

Odoo frontend assets and RTL transformation may require Node.js, npm, Less, and RTL CSS tooling.

Install Node.js and related packages.

```bash
sudo apt install -y \
    nodejs \
    npm \
    node-less \
    xfonts-75dpi \
    xfonts-base
```

Ensure the `node` binary is available.

```bash
sudo ln -sf /usr/bin/nodejs /usr/bin/node || true
```

Install global RTL and Less tools.

```bash
sudo npm install -g rtlcss less less-plugin-clean-css
```

Install Persian/Arabic-script compatible fonts.

```bash
sudo apt install -y \
    fonts-noto-core \
    fonts-noto-ui-core \
    fonts-kacst \
    fonts-kacst-one \
    fontconfig
```

Install Vazirmatn fonts for better Persian rendering.

```bash
sudo mkdir -p /usr/local/share/fonts/vazirmatn

for weight in Regular Medium SemiBold Bold Light; do
    sudo curl -fsSL -o "/usr/local/share/fonts/vazirmatn/Vazirmatn-${weight}.ttf" \
        "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/ttf/Vazirmatn-${weight}.ttf" || true
done

sudo fc-cache -fv
```

Verify font matching.

```bash
fc-match "Vazirmatn"
fc-match "Noto Naskh Arabic"
fc-match "KacstOne"
```

Verify Node.js tools.

```bash
node -v
npm -v
rtlcss --version || true
```

---

## 12. Phase 9: Patched wkhtmltopdf for Persian PDF Reports

Odoo requires a patched wkhtmltopdf build for reliable PDF headers, footers, and complex rendering.

Use the following installer. It tries newer Ubuntu codenames first and falls back to older compatible packages.

```bash
install_wkhtmltopdf() {
    BASE_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3"

    for codename in noble jammy bionic; do
        PKG="wkhtmltox_0.12.6.1-3.${codename}_amd64.deb"

        if curl -fsIL "${BASE_URL}/${PKG}" > /dev/null; then
            wget "${BASE_URL}/${PKG}"

            sudo dpkg -i "${PKG}" || true
            sudo apt --fix-broken install -y

            rm -f "${PKG}"
            return 0
        fi
    done

    return 1
}

if ! install_wkhtmltopdf; then
    echo "No suitable patched wkhtmltopdf package found. Trying distribution package..."
    sudo apt install -y wkhtmltopdf || true
fi
```

Verify wkhtmltopdf.

```bash
wkhtmltopdf --version
```

You should see a patched build, ideally containing:

```text
with patched qt
```

If it is not patched, Persian PDF reports may render incorrectly.

---

## 13. Phase 10: Python 3.12 and Odoo System Dependencies

Odoo 19 in this guide uses Python 3.12.

If Python 3.12 is not available in the default repositories, add the DeadSnakes PPA.

```bash
if ! apt-cache show python3.12 > /dev/null 2>&1; then
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
fi
```

Install Python 3.12.

```bash
sudo apt install -y \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip
```

Install Odoo system dependencies.

```bash
sudo apt install -y \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    libjpeg-dev \
    liblcms2-dev \
    libtiff5-dev \
    libwebp-dev \
    libfreetype-dev \
    libblas-dev \
    libatlas-base-dev
```

---

## 14. Phase 11: Odoo System User and Repository Deployment

Create the fixed Linux user.

```bash
sudo useradd -m -s /bin/bash odoo19 || true
echo "odoo19:999239" | sudo chpasswd
```

Create fixed directories.

```bash
sudo mkdir -p /home/odoo19/odoo19/{custom_addons,filestore,logs,backups}
```

Deploy the repository.

If `/home/odoo19/odoo19` is empty or does not contain a Git repository, clone the repository into a temporary directory and synchronize it into the final project directory. This preserves existing custom addon folders.

```bash
sudo -iu odoo19 bash -s <<'EOS'
set -e

if [ ! -d /home/odoo19/odoo19/.git ]; then
    rm -rf /home/odoo19/odoo19-src
    git clone https://github.com/ehsan-r97/odoo19.git /home/odoo19/odoo19-src
    rsync -a /home/odoo19/odoo19-src/ /home/odoo19/odoo19/
    rm -rf /home/odoo19/odoo19-src
fi
EOS
```

Set permissions.

```bash
sudo chown -R odoo19:odoo19 /home/odoo19/odoo19
sudo chmod 755 /home/odoo19/odoo19/custom_addons
```

---

## 15. Phase 12: Python Virtual Environment and Addon Requirements

Create and populate the Python virtual environment.

```bash
sudo -iu odoo19 bash -s <<'EOS'
set -e

cd /home/odoo19/odoo19

if [ ! -d venv ]; then
    python3.12 -m venv venv
fi

source venv/bin/activate

pip install --upgrade pip setuptools wheel

pip install -r requirements.txt

pip install \
    psycopg2-binary \
    "psycopg[binary]" \
    PyYAML \
    python-dotenv \
    redis \
    phonenumbers \
    pgvector \
    numpy \
    requests

if [ -d custom_addons ]; then
    find custom_addons -type f -name "requirements.txt" -print0 | \
    while IFS= read -r -d '' req_file; do
        echo "Installing dependencies from: ${req_file}"
        pip install -r "${req_file}"
    done
fi
EOS
```

---

## 16. Phase 13: Fixed Odoo Configuration File

Write the fixed `/home/odoo19/odoo19/odoo.conf`.

```bash
sudo tee /home/odoo19/odoo19/odoo.conf > /dev/null <<'EOF'
[options]

; =============================================================================
; SERVER
; =============================================================================
http_interface = 127.0.0.1
http_port = 8019
gevent_port = 8072
proxy_mode = True
server_wide_modules = base,web

; =============================================================================
; DATABASE THROUGH PGBOUNCER
; =============================================================================
db_host = 127.0.0.1
db_port = 6432
db_user = odoo19
db_password = 999239

db_maxconn = 32
db_sslmode = prefer
dbfilter = ^.*$
db_template = template1
unaccent = True

; =============================================================================
; ADDONS AND FILESTORE
; =============================================================================
addons_path = /home/odoo19/odoo19/odoo/addons,/home/odoo19/odoo19/addons,/home/odoo19/odoo19/custom_addons
data_dir = /home/odoo19/odoo19/filestore

; =============================================================================
; SECURITY / MASTER PASSWORD
; =============================================================================
admin_passwd = 999239
list_db = True

; =============================================================================
; LOGGING
; =============================================================================
logfile = /home/odoo19/odoo19/logs/odoo.log
log_level = info
log_handler = :INFO,werkzeug:WARNING,odoo.modules.registry:WARNING,odoo.addons.base.models.ir_attachment:WARNING

; =============================================================================
; PERFORMANCE / WORKERS
; =============================================================================
workers = 4
max_cron_threads = 2

limit_memory_soft = 1073741824
limit_memory_hard = 1610612736

limit_time_cpu = 60
limit_time_real = 120
limit_request = 1073741824

; =============================================================================
; TRANSLATION / PERSIAN SUPPORT
; =============================================================================
translate_modules = ['all']

; =============================================================================
; DEVELOPMENT / PRODUCTION SWITCH
; =============================================================================
dev_mode = False
demo = False
EOF

sudo chown odoo19:odoo19 /home/odoo19/odoo19/odoo.conf
sudo chmod 640 /home/odoo19/odoo19/odoo.conf
```

### Configuration Notes

| Parameter | Fixed Value | Reason |
|---|---:|---|
| `http_port` | 8019 | Odoo listens locally behind Nginx |
| `gevent_port` | 8072 | WebSocket/longpolling/evented service |
| `proxy_mode` | True | Required behind Nginx |
| `db_port` | 6432 | Uses PgBouncer |
| `db_template` | template1 | Inherits PostgreSQL AI/search extensions |
| `workers` | 4 | Balanced for fixed 16 GB RAM profile |
| `max_cron_threads` | 2 | Background job capacity |
| `limit_memory_soft` | 1 GB | Worker soft restart threshold |
| `limit_memory_hard` | 1.5 GB | Worker hard memory limit |
| `unaccent` | True | Better search behavior |
| `translate_modules` | all | Loads translation support for all modules |

---

## 17. Phase 14: Nginx Reverse Proxy, WebSocket, and Longpolling

Install Nginx.

```bash
sudo apt install -y nginx
```

Write the fixed main Nginx configuration.

```bash
sudo tee /etc/nginx/nginx.conf > /dev/null <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 4096;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    keepalive_timeout 65;
    types_hash_max_size 2048;

    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1100;

    gzip_types
        text/css
        text/plain
        text/xml
        application/xml
        application/json
        application/javascript
        application/x-javascript
        image/svg+xml
        font/woff
        font/woff2;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
```

Write the fixed Odoo site configuration.

```bash
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
    client_body_buffer_size 128k;

    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;
    proxy_read_timeout 900s;

    reset_timedout_connection on;

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
        expires 7d;
        add_header Cache-Control "public, no-transform";
        proxy_pass http://odoo;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
EOF
```

Enable the site.

```bash
sudo ln -sf /etc/nginx/sites-available/odoo19 /etc/nginx/sites-enabled/odoo19
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl restart nginx
```

---

## 18. Phase 15: Odoo systemd Service

Create the fixed systemd service.

```bash
sudo tee /etc/systemd/system/odoo19.service > /dev/null <<'EOF'
[Unit]
Description=Odoo 19
After=network-online.target postgresql.service pgbouncer.service redis-server.service
Wants=network-online.target

[Service]
Type=simple
User=odoo19
Group=odoo19
WorkingDirectory=/home/odoo19/odoo19

ExecStart=/home/odoo19/odoo19/venv/bin/python3 /home/odoo19/odoo19/odoo-bin -c /home/odoo19/odoo19/odoo.conf

Restart=on-failure
RestartSec=5

LimitNOFILE=65536
LimitNPROC=4096

StandardOutput=journal
StandardError=journal
SyslogIdentifier=odoo19

[Install]
WantedBy=multi-user.target
EOF
```

Reload systemd.

```bash
sudo systemctl daemon-reload
```

Do not start Odoo yet. Initialize the database first.

---

## 19. Phase 16: Database Initialization and Persian Language Loading

Stop Odoo if it is running.

```bash
sudo systemctl stop odoo19 || true
```

Initialize the database, enable PostgreSQL extensions inside the Odoo database, load Persian, and regenerate base/web assets.

```bash
sudo -iu odoo19 bash -s <<'EOS'
set -e

cd /home/odoo19/odoo19
source venv/bin/activate

DB="odoo19"

echo "Checking whether database ${DB} exists..."

if ! PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d postgres -Atc \
    "SELECT 1 FROM pg_database WHERE datname='${DB}'" | grep -q 1; then

    echo "Creating database ${DB}..."
    ./odoo-bin -c odoo.conf -d "${DB}" -i base --stop-after-init
else
    echo "Database ${DB} already exists."
fi

echo "Ensuring PostgreSQL extensions exist inside ${DB}..."

PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d "${DB}" -c \
"CREATE EXTENSION IF NOT EXISTS vector;
 CREATE EXTENSION IF NOT EXISTS pg_trgm;
 CREATE EXTENSION IF NOT EXISTS unaccent;
 CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

echo "Loading Persian language and updating base/web assets..."

./odoo-bin -c odoo.conf -d "${DB}" \
    --load-language=fa_IR \
    -u base,web \
    --stop-after-init
EOS
```

---

## 20. Phase 17: Start and Verify Odoo

Start Odoo.

```bash
sudo systemctl enable --now odoo19
sudo systemctl status odoo19 --no-pager
```

Check listening ports.

```bash
sudo ss -ltnp | grep -E ':(80|6432|8019|8072|5432|6379)\b'
```

Expected services:

| Port | Service |
|---:|---|
| 80 | Nginx |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 6432 | PgBouncer |
| 8019 | Odoo HTTP |
| 8072 | Odoo evented/WebSocket/longpolling |

Test HTTP.

```bash
curl -I http://127.0.0.1
```

You should receive an Odoo HTTP response, commonly a redirect such as:

```text
HTTP/1.1 303 SEE OTHER
```

Open in browser:

```text
http://127.0.0.1
```

Or from another machine:

```text
http://SERVER_IP
```

Default database:

```text
odoo19
```

Master password:

```text
999239
```

---

## 21. Persian RTL Support in Odoo 19

This installation supports Persian `fa_IR` only. Arabic is not configured.

### 21.1 System-Level Persian Support

Already installed:

- Persian locale: `fa_IR.UTF-8`
- UTF-8 encoding
- Vazirmatn fonts
- Noto fonts
- Kacst fonts
- Fontconfig cache
- Patched wkhtmltopdf
- Node.js
- npm
- rtlcss
- Less
- clean-css

These components support:

- Persian browser UI.
- Persian RTL layout.
- Persian input.
- Persian PDF reports.
- Correct glyph rendering.
- Right-to-left CSS transformation.

### 21.2 Activate Persian Inside Odoo

1. Log in as administrator.
2. Go to:

```text
Settings → Translations → Languages
```

3. Activate:

```text
Persian (fa_IR)
```

4. Open the Persian language record.
5. Confirm direction is:

```text
RTL
```

6. Load translations.

If the language does not appear correctly, force the RTL direction at database level:

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 -c \
"UPDATE res_lang SET direction = 'rtl' WHERE code = 'fa_IR';"
```

Then restart Odoo:

```bash
sudo systemctl restart odoo19
```

### 21.3 Set User Language to Persian

1. Go to:

```text
Settings → Users and Companies → Users
```

2. Open your user.
3. Set:

```text
Language = Persian (fa_IR)
```

4. Save.
5. Log out.
6. Log in again.

The interface should render right-to-left.

### 21.4 Persian PDF Reports

For Persian PDF reports, ensure:

- The partner/company language is Persian where relevant.
- wkhtmltopdf is patched.
- Vazirmatn/Noto/Kacst fonts are installed.
- Odoo assets have been regenerated.

Regenerate assets:

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate
./odoo-bin -c odoo.conf -d odoo19 -u base,web --stop-after-init
EOS

sudo systemctl start odoo19
```

Clear browser cache and perform a hard refresh:

```text
Ctrl + Shift + R
```

### 21.5 Custom Addon RTL Best Practices

When developing custom addons:

- Do not hardcode `left` and `right` CSS properties when possible.
- Prefer logical properties:

```css
margin-inline-start
margin-inline-end
padding-inline-start
padding-inline-end
text-align: start
text-align: end
```

- Include CSS files in Odoo asset bundles.
- After changing assets, upgrade `web` or your module.
- Test with user language `fa_IR`.

---

## 22. PostgreSQL AI and Vector Search Support

This installation includes PostgreSQL AI/vector support using `pgvector`.

### 22.1 Installed AI/Search Extensions

The following extensions are enabled:

| Extension | Purpose |
|---|---|
| `vector` | Vector similarity search for AI/RAG |
| `pg_trgm` | Trigram fuzzy text search |
| `unaccent` | Accent-insensitive search |
| `pg_stat_statements` | Query performance analysis |

### 22.2 Python AI Packages

Installed in the Odoo virtual environment:

```text
pgvector
numpy
requests
psycopg2-binary
psycopg[binary]
```

These support:

- Vector insertion.
- Vector similarity queries.
- Embedding storage.
- AI-related Python integrations.

### 22.3 Optional Local AI Backend with Ollama

If you want local embeddings and local AI inference, install Ollama.

```bash
curl -fsSL https://ollama.com/install.sh | sh

sudo systemctl enable --now ollama
```

Pull a Persian/English compatible embedding model.

```bash
ollama pull nomic-embed-text
```

Test:

```bash
ollama run nomic-embed-text "test"
```

Ollama listens on:

```text
127.0.0.1:11434
```

### 22.4 Example Vector Table for AI Documents

This example uses 768 dimensions, compatible with `nomic-embed-text`.

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 <<'EOS'
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS ai_document_embedding (
    id BIGSERIAL PRIMARY KEY,
    res_model VARCHAR NOT NULL,
    res_id BIGINT NOT NULL,
    chunk_text TEXT NOT NULL,
    embedding vector(768) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ai_document_embedding_res_idx
ON ai_document_embedding (res_model, res_id);

CREATE INDEX IF NOT EXISTS ai_document_embedding_vector_idx
ON ai_document_embedding
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
EOS
```

Example similarity query:

```sql
SELECT
    res_model,
    res_id,
    chunk_text,
    1 - (embedding <=> CAST(:embedding AS vector)) AS similarity
FROM ai_document_embedding
ORDER BY embedding <=> CAST(:embedding AS vector)
LIMIT 5;
```

### 22.5 AI Performance Notes

For large vector tables:

- Use `ivfflat` for moderate datasets.
- Use `hnsw` if your pgvector version supports it and your dataset is large.
- Keep embeddings normalized when using cosine distance.
- Monitor slow queries using `pg_stat_statements`.

---

## 23. Sub Git Addon Folder Management

Your repository is designed to contain multiple independent Git-based addon folders, usually under:

```text
/home/odoo19/odoo19/custom_addons
```

Example:

```text
/home/odoo19/odoo19/custom_addons/my_first_addon
/home/odoo19/odoo19/custom_addons/my_second_addon
/home/odoo19/odoo19/custom_addons/customer_specific_module
```

Each addon folder may have its own `.git` directory.

### 23.1 Recommended Parent Repository Policy

The parent Odoo repository should not track the internal contents of independent addon repositories.

Create or update `.gitignore` in the parent repository:

```bash
sudo tee /home/odoo19/odoo19/.gitignore > /dev/null <<'EOF'
# Python
__pycache__/
*.py[cod]
*.egg-info/
.eggs/

# Virtual environment
venv/

# Odoo runtime data
filestore/
logs/
backups/

# Environment files
.env

# Editors
.idea/
.vscode/
*.swp

# Node
node_modules/

# Independent addon Git repositories
custom_addons/*
!custom_addons/.gitkeep
EOF

sudo chown odoo19:odoo19 /home/odoo19/odoo19/.gitignore
```

Create the keep file:

```bash
sudo -iu odoo19 touch /home/odoo19/odoo19/custom_addons/.gitkeep
```

### 23.2 If an Addon Folder Was Already Added to the Parent Repository

Remove it from the parent index without deleting local files:

```bash
cd /home/odoo19/odoo19
git rm -r --cached custom_addons/ADDON_NAME
```

Replace `ADDON_NAME` with the actual addon folder name.

Then commit:

```bash
git commit -m "Stop tracking independent addon repository"
```

### 23.3 Update All Independent Addon Repositories

```bash
sudo -iu odoo19 bash -s <<'EOS'
set -e

cd /home/odoo19/odoo19/custom_addons

for addon_dir in */; do
    if [ -d "${addon_dir}/.git" ]; then
        echo "------------------------------------------------------------"
        echo "Updating: ${addon_dir}"
        echo "------------------------------------------------------------"
        git -C "${addon_dir}" fetch --all --prune
        git -C "${addon_dir}" pull --ff-only
    fi
done
EOS
```

### 23.4 Show Status of All Independent Addon Repositories

```bash
sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19/custom_addons

for addon_dir in */; do
    if [ -d "${addon_dir}/.git" ]; then
        echo "------------------------------------------------------------"
        echo "Status: ${addon_dir}"
        echo "------------------------------------------------------------"
        git -C "${addon_dir}" status --short --branch
    fi
done
EOS
```

### 23.5 Alternative: Use Git Submodules

If you want the parent repository to pin exact addon commits, convert addon folders to Git submodules.

Example:

```bash
cd /home/odoo19/odoo19

git submodule add https://github.com/your-org/your-addon.git custom_addons/your-addon
git submodule update --init --recursive
```

For this repository, independent sub-Git folders are supported either by:

- Ignoring them in the parent repository, or
- Tracking them as Git submodules.

Choose one approach and keep it consistent.

---

## 24. Odoo Addon Development Workflow

This repository is intended for Odoo addon development.

### 24.1 Create a New Addon Scaffold

```bash
sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate

./odoo-bin scaffold new_addon custom_addons
EOS
```

This creates:

```text
/home/odoo19/odoo19/custom_addons/new_addon
```

### 24.2 Initialize the New Addon as Its Own Git Repository

```bash
sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19/custom_addons/new_addon

git init
git add .
git commit -m "Initial Odoo 19 addon structure"
EOS
```

Then connect it to your remote repository:

```bash
cd /home/odoo19/odoo19/custom_addons/new_addon
git remote add origin https://github.com/your-org/new_addon.git
git push -u origin main
```

### 24.3 Install a New Addon

Stop Odoo:

```bash
sudo systemctl stop odoo19
```

Update the application list:

```bash
sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate

./odoo-bin -c odoo.conf -d odoo19 -u base --stop-after-init
EOS
```

Start Odoo:

```bash
sudo systemctl start odoo19
```

Then install from UI:

```text
Apps → Update Apps List → Search new_addon → Install
```

### 24.4 Upgrade an Existing Addon

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate

./odoo-bin -c odoo.conf -d odoo19 -u new_addon --stop-after-init
EOS

sudo systemctl start odoo19
```

### 24.5 Upgrade Multiple Addons

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate

./odoo-bin -c odoo.conf -d odoo19 \
    -u new_addon,another_addon,base,web \
    --stop-after-init
EOS

sudo systemctl start odoo19
```

### 24.6 Run Odoo in Development Mode Manually

Use this only for development.

```bash
sudo systemctl stop odoo19

sudo apt install -y tmux || true

tmux new -s odoo19-dev

sudo -iu odoo19 bash -lc '
cd /home/odoo19/odoo19
source venv/bin/activate
./odoo-bin -c odoo.conf -d odoo19 --dev=reload,qweb,xml
'
```

Detach from tmux:

```text
Ctrl+B then D
```

Attach later:

```bash
tmux attach -t odoo19-dev
```

Stop manual development mode and return to service:

```bash
tmux kill-session -t odoo19-dev || true
sudo systemctl start odoo19
```

### 24.7 Run Automated Tests for an Addon

Create a separate test database:

```bash
sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate

./odoo-bin -c odoo.conf \
    -d test_odoo19 \
    -i new_addon \
    --test-enable \
    --stop-after-init
EOS
```

Delete the test database when finished:

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d postgres -c "DROP DATABASE IF EXISTS test_odoo19;"
```

---

## 25. Persian Translation Workflow for Custom Addons

### 25.1 Add Persian Translation Files

Inside your addon, create:

```text
custom_addons/new_addon/i18n/fa_IR.po
```

Odoo translation files usually live in:

```text
addon_name/i18n/
```

### 25.2 Update Persian Translations from Code

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate

./odoo-bin -c odoo.conf \
    -d odoo19 \
    -u new_addon \
    --load-language=fa_IR \
    --stop-after-init
EOS

sudo systemctl start odoo19
```

### 25.3 Export Persian Translations from Odoo UI

Go to:

```text
Settings → Translations → Export Translation
```

Select:

```text
Language: Persian (fa_IR)
Format: Gettext Po file
```

Export and place the file inside your addon:

```text
custom_addons/new_addon/i18n/fa_IR.po
```

### 25.4 Import Persian Translations into Odoo

Go to:

```text
Settings → Translations → Import Translations
```

Upload:

```text
fa_IR.po
```

Then upgrade the module:

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate
./odoo-bin -c odoo.conf -d odoo19 -u new_addon --stop-after-init
EOS

sudo systemctl start odoo19
```

---

## 26. Performance Monitoring

### 26.1 Odoo Service Logs

```bash
sudo journalctl -u odoo19 -f
```

Odoo file log:

```bash
tail -f /home/odoo19/odoo19/logs/odoo.log
```

### 26.2 PostgreSQL Slow Queries

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 -c \
"SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;"
```

### 26.3 Active PostgreSQL Connections

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d postgres -c \
"SELECT
    state,
    count(*)
FROM pg_stat_activity
GROUP BY state
ORDER BY count DESC;"
```

### 26.4 PgBouncer Statistics

Connect to the PgBouncer admin database:

```bash
psql -h 127.0.0.1 -p 6432 -U odoo19 -d pgbouncer
```

Run:

```sql
SHOW STATS;
SHOW POOLS;
SHOW CLIENTS;
SHOW SERVERS;
```

Exit:

```sql
\q
```

### 26.5 Redis Statistics

```bash
redis-cli info stats
redis-cli info memory
redis-cli client list
```

### 26.6 Nginx Status

```bash
sudo systemctl status nginx --no-pager
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### 26.7 System Resource Usage

```bash
htop
```

If `htop` is not installed:

```bash
sudo apt install -y htop
```

Check disk:

```bash
df -h
```

Check memory:

```bash
free -h
```

Check open ports:

```bash
sudo ss -ltnp
```

---

## 27. Backup and Restore

### 27.1 Full Backup

This backup stops Odoo, dumps PostgreSQL, copies filestore, copies custom addons, copies logs, and restarts Odoo.

```bash
sudo systemctl stop odoo19

BACKUP_DIR="/home/odoo19/odoo19/backups/manual_$(date +%Y%m%d_%H%M%S)"
sudo -u odoo19 mkdir -p "${BACKUP_DIR}"

PGPASSWORD='999239' pg_dump \
    -h 127.0.0.1 \
    -p 5432 \
    -U odoo19 \
    -Fc \
    odoo19 > "${BACKUP_DIR}/odoo19.dump"

sudo -u odoo19 rsync -a /home/odoo19/odoo19/filestore "${BACKUP_DIR}/filestore"
sudo -u odoo19 rsync -a /home/odoo19/odoo19/custom_addons "${BACKUP_DIR}/custom_addons"
sudo -u odoo19 cp /home/odoo19/odoo19/odoo.conf "${BACKUP_DIR}/odoo.conf"
sudo -u odoo19 tar -czf "${BACKUP_DIR}/logs.tar.gz" -C /home/odoo19/odoo19 logs

sudo chown -R odoo19:odoo19 "${BACKUP_DIR}"

sudo systemctl start odoo19

echo "Backup created at: ${BACKUP_DIR}"
```

### 27.2 Restore Full Backup

Replace `BACKUP_PATH` with the actual backup directory.

```bash
BACKUP_PATH="/home/odoo19/odoo19/backups/manual_YYYYMMDD_HHMMSS"

sudo systemctl stop odoo19

PGPASSWORD='999239' psql -h 127.0.0.1 -p 5432 -U odoo19 -d postgres -c "DROP DATABASE IF EXISTS odoo19;"
PGPASSWORD='999239' psql -h 127.0.0.1 -p 5432 -U odoo19 -d postgres -c "CREATE DATABASE odoo19 OWNER odoo19;"

PGPASSWORD='999239' pg_restore \
    -h 127.0.0.1 \
    -p 5432 \
    -U odoo19 \
    -d odoo19 \
    --clean \
    --if-exists \
    "${BACKUP_PATH}/odoo19.dump"

sudo -u odoo19 rsync -a --delete "${BACKUP_PATH}/filestore/" /home/odoo19/odoo19/filestore/
sudo -u odoo19 rsync -a "${BACKUP_PATH}/custom_addons/" /home/odoo19/odoo19/custom_addons/
sudo cp "${BACKUP_PATH}/odoo.conf" /home/odoo19/odoo19/odoo.conf

sudo chown -R odoo19:odoo19 /home/odoo19/odoo19

sudo systemctl start odoo19
```

### 27.3 Database-Only Backup

```bash
PGPASSWORD='999239' pg_dump \
    -h 127.0.0.1 \
    -p 5432 \
    -U odoo19 \
    -Fc \
    odoo19 > /home/odoo19/odoo19/backups/odoo19_db_only.dump
```

### 27.4 Database-Only Restore

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 5432 -U odoo19 -d postgres -c "DROP DATABASE IF EXISTS odoo19;"
PGPASSWORD='999239' psql -h 127.0.0.1 -p 5432 -U odoo19 -d postgres -c "CREATE DATABASE odoo19 OWNER odoo19;"

PGPASSWORD='999239' pg_restore \
    -h 127.0.0.1 \
    -p 5432 \
    -U odoo19 \
    -d odoo19 \
    --clean \
    --if-exists \
    /home/odoo19/odoo19/backups/odoo19_db_only.dump
```

---

## 28. Log Rotation

Install logrotate if missing.

```bash
sudo apt install -y logrotate
```

Create fixed log rotation for Odoo.

```bash
sudo tee /etc/logrotate.d/odoo19 > /dev/null <<'EOF'
/home/odoo19/odoo19/logs/odoo.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 odoo19 odoo19
    sharedscripts
    postrotate
        systemctl kill -s USR2 odoo19.service || true
    endscript
}
EOF
```

Test:

```bash
sudo logrotate -d /etc/logrotate.d/odoo19
```

---

## 29. Troubleshooting

### 29.1 Odoo Returns 502 Through Nginx

Check Odoo:

```bash
sudo systemctl status odoo19 --no-pager
sudo journalctl -u odoo19 -n 100 --no-pager
```

Check ports:

```bash
sudo ss -ltnp | grep -E ':(8019|8072)'
```

Check Nginx error log:

```bash
sudo tail -n 100 /var/log/nginx/error.log
```

Common causes:

- Odoo is not running.
- Wrong `http_port`.
- Wrong `gevent_port`.
- Firewall blocking local ports.
- PostgreSQL/PgBouncer unavailable.

---

### 29.2 Odoo Cannot Connect to PostgreSQL Through PgBouncer

Test direct PostgreSQL:

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 5432 -U odoo19 -d postgres -c "SELECT 1;"
```

Test PgBouncer:

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d postgres -c "SELECT 1;"
```

Check PgBouncer log:

```bash
sudo journalctl -u pgbouncer -n 100 --no-pager
```

Common causes:

- Wrong SCRAM secret in `/etc/pgbouncer/userlist.txt`.
- PostgreSQL user password changed after PgBouncer userlist was generated.
- `pg_hba.conf` does not allow SCRAM-SHA-256.
- PgBouncer is not running.

Rebuild PgBouncer userlist:

```bash
SCRAM_SECRET=$(sudo -u postgres psql -Atc "SELECT rolpassword FROM pg_authid WHERE rolname='odoo19';")

printf '"odoo19" "%s"\n' "$SCRAM_SECRET" | \
    sudo tee /etc/pgbouncer/userlist.txt > /dev/null

sudo chown pgbouncer:pgbouncer /etc/pgbouncer/userlist.txt
sudo chmod 600 /etc/pgbouncer/userlist.txt

sudo systemctl restart pgbouncer
```

---

### 29.3 Persian Interface Does Not Appear RTL

Check language direction:

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 -c \
"SELECT code, name, direction FROM res_lang WHERE code = 'fa_IR';"
```

Expected:

```text
 direction
-----------
 rtl
```

If not:

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 -c \
"UPDATE res_lang SET direction = 'rtl' WHERE code = 'fa_IR';"
```

Regenerate assets:

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate
./odoo-bin -c odoo.conf -d odoo19 -u base,web --stop-after-init
EOS

sudo systemctl start odoo19
```

Clear browser cache.

---

### 29.4 Persian Characters Appear as Boxes in PDF

Check fonts:

```bash
fc-match "Vazirmatn"
fc-match "Noto Naskh Arabic"
fc-match "KacstOne"
```

Rebuild font cache:

```bash
sudo fc-cache -fv
```

Check wkhtmltopdf:

```bash
wkhtmltopdf --version
```

Ensure it is patched.

Restart Odoo:

```bash
sudo systemctl restart odoo19
```

---

### 29.5 Persian Text Is Disconnected or Rendered Incorrectly in PDF

This usually means wkhtmltopdf is not patched or fonts are missing.

Reinstall patched wkhtmltopdf:

```bash
sudo apt remove -y wkhtmltopdf wkhtmltox || true

install_wkhtmltopdf() {
    BASE_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3"

    for codename in noble jammy bionic; do
        PKG="wkhtmltox_0.12.6.1-3.${codename}_amd64.deb"

        if curl -fsIL "${BASE_URL}/${PKG}" > /dev/null; then
            wget "${BASE_URL}/${PKG}"
            sudo dpkg -i "${PKG}" || true
            sudo apt --fix-broken install -y
            rm -f "${PKG}"
            return 0
        fi
    done

    return 1
}

install_wkhtmltopdf

sudo fc-cache -fv
sudo systemctl restart odoo19
```

---

### 29.6 WebSocket or Chat Does Not Work

Check port 8072:

```bash
sudo ss -ltnp | grep 8072
```

Check Nginx upstream:

```bash
sudo nginx -T | grep -A 5 "upstream odoochat"
```

Check Odoo log:

```bash
sudo journalctl -u odoo19 -n 100 --no-pager
```

Ensure `gevent_port = 8072` exists in:

```text
/home/odoo19/odoo19/odoo.conf
```

Restart Odoo:

```bash
sudo systemctl restart odoo19
```

---

### 29.7 New Custom Addon Does Not Appear in Apps

Ensure the addon path is included:

```text
addons_path = /home/odoo19/odoo19/odoo/addons,/home/odoo19/odoo19/addons,/home/odoo19/odoo19/custom_addons
```

Ensure the addon folder contains:

```text
__manifest__.py
```

Ensure the manifest has:

```python
'installable': True,
'application': True,
```

Restart Odoo and update apps list:

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate
./odoo-bin -c odoo.conf -d odoo19 -u base --stop-after-init
EOS

sudo systemctl start odoo19
```

Then in UI:

```text
Apps → Update Apps List
```

---

### 29.8 Permission Errors on Filestore or Logs

Fix permissions:

```bash
sudo chown -R odoo19:odoo19 /home/odoo19/odoo19
sudo chmod -R u+rwX /home/odoo19/odoo19/filestore
sudo chmod -R u+rwX /home/odoo19/odoo19/logs
sudo chmod 755 /home/odoo19/odoo19/custom_addons
```

Restart Odoo:

```bash
sudo systemctl restart odoo19
```

---

### 29.9 PostgreSQL Extension Missing Inside Odoo Database

Enable extensions manually:

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 -c \
"CREATE EXTENSION IF NOT EXISTS vector;
 CREATE EXTENSION IF NOT EXISTS pg_trgm;
 CREATE EXTENSION IF NOT EXISTS unaccent;
 CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

Restart Odoo:

```bash
sudo systemctl restart odoo19
```

---

## 30. Final Verification Checklist

Run these checks after installation.

### 30.1 Services

```bash
sudo systemctl status postgresql --no-pager
sudo systemctl status pgbouncer --no-pager
sudo systemctl status redis-server --no-pager
sudo systemctl status nginx --no-pager
sudo systemctl status odoo19 --no-pager
```

All should be active.

---

### 30.2 Ports

```bash
sudo ss -ltnp | grep -E ':(80|6432|8019|8072|5432|6379)\b'
```

Expected:

| Port | Service |
|---:|---|
| 80 | Nginx |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 6432 | PgBouncer |
| 8019 | Odoo |
| 8072 | Odoo evented/WebSocket/longpolling |

---

### 30.3 PostgreSQL Direct Connection

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 5432 -U odoo19 -d postgres -c "SELECT version();"
```

---

### 30.4 PgBouncer Connection

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d postgres -c "SELECT 1;"
```

---

### 30.5 Odoo Database Extensions

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 -c \
"SELECT extname, extversion FROM pg_extension ORDER BY extname;"
```

Expected at least:

```text
vector
pg_trgm
unaccent
pg_stat_statements
```

---

### 30.6 Persian Language Record

```bash
PGPASSWORD='999239' psql -h 127.0.0.1 -p 6432 -U odoo19 -d odoo19 -c \
"SELECT code, name, direction FROM res_lang WHERE code = 'fa_IR';"
```

Expected direction:

```text
rtl
```

---

### 30.7 Redis

```bash
redis-cli ping
```

Expected:

```text
PONG
```

---

### 30.8 Nginx HTTP Test

```bash
curl -I http://127.0.0.1
```

Expected:

```text
HTTP/1.1 303 SEE OTHER
```

or another valid Odoo HTTP response.

---

### 30.9 wkhtmltopdf

```bash
wkhtmltopdf --version
```

Expected:

```text
wkhtmltopdf 0.12.6
...
with patched qt
```

---

### 30.10 RTL Tooling

```bash
node -v
npm -v
rtlcss --version || true
```

---

### 30.11 Persian Fonts

```bash
fc-match "Vazirmatn"
fc-match "Noto Naskh Arabic"
fc-match "KacstOne"
```

---

### 30.12 Odoo Log

```bash
sudo tail -n 100 /home/odoo19/odoo19/logs/odoo.log
```

Look for:

```text
Modules loaded
HTTP service (0.0.0.0:8019) running
```

or equivalent Odoo 19 startup messages.

---

## Quick Daily Commands

### Start Odoo

```bash
sudo systemctl start odoo19
```

### Stop Odoo

```bash
sudo systemctl stop odoo19
```

### Restart Odoo

```bash
sudo systemctl restart odoo19
```

### Odoo Status

```bash
sudo systemctl status odoo19 --no-pager
```

### Follow Odoo Logs

```bash
sudo journalctl -u odoo19 -f
```

### Upgrade One Addon

```bash
sudo systemctl stop odoo19

sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19
source venv/bin/activate
./odoo-bin -c odoo.conf -d odoo19 -u new_addon --stop-after-init
EOS

sudo systemctl start odoo19
```

### Update All Independent Addon Git Repositories

```bash
sudo -iu odoo19 bash -s <<'EOS'
cd /home/odoo19/odoo19/custom_addons

for addon_dir in */; do
    if [ -d "${addon_dir}/.git" ]; then
        echo "Updating: ${addon_dir}"
        git -C "${addon_dir}" fetch --all --prune
        git -C "${addon_dir}" pull --ff-only
    fi
done
EOS
```

### Full Manual Backup

```bash
sudo systemctl stop odoo19

BACKUP_DIR="/home/odoo19/odoo19/backups/manual_$(date +%Y%m%d_%H%M%S)"
sudo -u odoo19 mkdir -p "${BACKUP_DIR}"

PGPASSWORD='999239' pg_dump -h 127.0.0.1 -p 5432 -U odoo19 -Fc odoo19 > "${BACKUP_DIR}/odoo19.dump"

sudo -u odoo19 rsync -a /home/odoo19/odoo19/filestore "${BACKUP_DIR}/filestore"
sudo -u odoo19 rsync -a /home/odoo19/odoo19/custom_addons "${BACKUP_DIR}/custom_addons"
sudo -u odoo19 cp /home/odoo19/odoo19/odoo.conf "${BACKUP_DIR}/odoo.conf"

sudo chown -R odoo19:odoo19 "${BACKUP_DIR}"

sudo systemctl start odoo19

echo "Backup created at: ${BACKUP_DIR}"
```

---

## End of README
