# Bare Metal Deployment

This guide covers deploying Vulcan directly on Linux servers without containerization, suitable for on-premises installations or dedicated servers.

## Prerequisites

- Ubuntu 20.04+ or RHEL/CentOS 8+ server
- Root or sudo access
- Minimum 2GB RAM, 2 CPU cores
- PostgreSQL 12+ database server
- Domain name with SSL certificate (recommended)

## System Preparation

### 1. Update System Packages

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get upgrade -y

# RHEL/CentOS
sudo yum update -y
```

### 2. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y build-essential git curl wget \
  libpq-dev libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libffi-dev libgdbm-dev libncurses5-dev \
  automake libtool bison nodejs npm nginx

# RHEL/CentOS
sudo yum groupinstall -y "Development Tools"
sudo yum install -y git curl wget postgresql-devel \
  openssl-devel readline-devel zlib-devel libyaml-devel \
  libffi-devel gdbm-devel ncurses-devel automake \
  libtool bison nodejs npm nginx
```

## Ruby Installation

### Using rbenv (Recommended)

```bash
# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install ruby-build
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Install Ruby 3.4.7
rbenv install 3.4.7
rbenv global 3.4.7
ruby -v  # Verify installation
```

### Using RVM (Alternative)

```bash
# Install RVM
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm

# Install Ruby 3.4.7
rvm install 3.4.7
rvm use 3.4.7 --default
ruby -v  # Verify installation
```

## PostgreSQL Setup

### Install PostgreSQL

```bash
# Ubuntu/Debian
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# RHEL/CentOS
sudo yum install -y postgresql-server postgresql-contrib
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Create Database and User

```bash
sudo -u postgres psql

# In PostgreSQL prompt:
CREATE USER vulcan_user WITH PASSWORD 'secure_password';
CREATE DATABASE vulcan_production OWNER vulcan_user;
GRANT ALL PRIVILEGES ON DATABASE vulcan_production TO vulcan_user;
\q
```

## Application Deployment

### 1. Create Application User

```bash
sudo useradd -m -s /bin/bash vulcan
sudo usermod -aG sudo vulcan  # Optional: give sudo access
```

### 2. Clone Repository

```bash
sudo su - vulcan
git clone https://github.com/mitre/vulcan.git /var/www/vulcan
cd /var/www/vulcan
```

### 3. Install Application Dependencies

```bash
# Install bundler
gem install bundler

# Install Ruby dependencies
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install

# Install Node.js dependencies
npm install -g pnpm
pnpm install --prod
```

### 4. Configure Application

```bash
# Copy and edit configuration
cp config/vulcan.default.yml config/vulcan.yml
nano config/vulcan.yml

# Create .env file for environment variables
cat > .env.production << EOF
RAILS_ENV=production
DATABASE_URL=postgresql://vulcan_user:secure_password@localhost/vulcan_production
SECRET_KEY_BASE=$(bundle exec rails secret)
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=false
VULCAN_CONTACT_EMAIL=admin@example.com  # Also used as default SMTP username
VULCAN_APP_URL=https://vulcan.example.com
# For SMTP email delivery, add:
# VULCAN_ENABLE_SMTP=true
# VULCAN_SMTP_ADDRESS=smtp.example.com
# VULCAN_SMTP_PORT=587
# VULCAN_SMTP_AUTHENTICATION=plain
# VULCAN_SMTP_SERVER_PASSWORD=your_smtp_password
# Note: VULCAN_SMTP_SERVER_USERNAME defaults to VULCAN_CONTACT_EMAIL
EOF
```

### 5. Setup Database

```bash
# Load environment variables
export $(cat .env.production | xargs)

# Run database migrations
bundle exec rails db:migrate

# Precompile assets
bundle exec rails assets:precompile

# Create admin user (optional)
bundle exec rails c
# In Rails console:
User.create!(
  email: 'admin@example.com',
  password: 'secure_password',
  admin: true,
  confirmed_at: Time.now
)
exit
```

## Web Server Configuration

### Nginx with Puma

1. **Configure Puma** (`config/puma.rb`):

```ruby
# Puma configuration
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

preload_app!

port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "production" }

pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Allow puma to be restarted by rails restart command
plugin :tmp_restart
```

2. **Configure Nginx** (`/etc/nginx/sites-available/vulcan`):

```nginx
upstream vulcan_app {
    server unix:///var/www/vulcan/tmp/sockets/puma.sock;
}

server {
    listen 80;
    server_name vulcan.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name vulcan.example.com;

    ssl_certificate /etc/ssl/certs/vulcan.crt;
    ssl_certificate_key /etc/ssl/private/vulcan.key;

    root /var/www/vulcan/public;
    client_max_body_size 100M;

    location / {
        try_files $uri @app;
    }

    location @app {
        proxy_pass http://vulcan_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Ssl on;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-Host $host;
    }

    location ~ ^/(assets|packs)/ {
        gzip_static on;
        expires 1y;
        add_header Cache-Control public;
        add_header Last-Modified "";
        add_header ETag "";
    }

    error_page 500 502 503 504 /500.html;
    error_page 404 /404.html;
    error_page 422 /422.html;
}
```

3. **Enable site**:

```bash
sudo ln -s /etc/nginx/sites-available/vulcan /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Process Management with systemd

### Create systemd Service

```bash
sudo nano /etc/systemd/system/vulcan.service
```

```ini
[Unit]
Description=Vulcan Puma Application Server
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=vulcan
WorkingDirectory=/var/www/vulcan
Environment="RAILS_ENV=production"
EnvironmentFile=/var/www/vulcan/.env.production

ExecStart=/home/vulcan/.rbenv/shims/bundle exec puma -C config/puma.rb
ExecReload=/bin/kill -USR2 $MAINPID
ExecStop=/bin/kill -TERM $MAINPID

Restart=always
RestartSec=10

StandardOutput=append:/var/log/vulcan/puma.log
StandardError=append:/var/log/vulcan/puma.error.log

[Install]
WantedBy=multi-user.target
```

### Enable and Start Service

```bash
# Create log directory
sudo mkdir -p /var/log/vulcan
sudo chown vulcan:vulcan /var/log/vulcan

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable vulcan.service
sudo systemctl start vulcan.service
sudo systemctl status vulcan.service
```

## SSL Certificate Setup

### Using Let's Encrypt

```bash
# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx  # Ubuntu
sudo yum install -y certbot python3-certbot-nginx      # RHEL/CentOS

# Obtain certificate
sudo certbot --nginx -d vulcan.example.com

# Auto-renewal
sudo certbot renew --dry-run
```

### Using Self-Signed Certificate (Development)

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/vulcan.key \
  -out /etc/ssl/certs/vulcan.crt
```

## Firewall Configuration

```bash
# Ubuntu with ufw
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable

# RHEL/CentOS with firewalld
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## Log Rotation

Create `/etc/logrotate.d/vulcan`:

```text
/var/log/vulcan/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 vulcan vulcan
    sharedscripts
    postrotate
        systemctl reload vulcan.service
    endscript
}
```

## Monitoring

### Health Check Endpoint

```bash
# Add to monitoring system
curl https://vulcan.example.com/health
```

### System Monitoring

```bash
# Install monitoring tools
sudo apt-get install -y htop iotop nethogs

# Monitor application
sudo journalctl -u vulcan -f
tail -f /var/log/vulcan/puma.log
```

## Backup Strategy

### Database Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-vulcan.sh

BACKUP_DIR="/var/backups/vulcan"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="vulcan_production"

mkdir -p $BACKUP_DIR

# Database backup
pg_dump -U vulcan_user -h localhost $DB_NAME | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Application files backup
tar -czf $BACKUP_DIR/files_$DATE.tar.gz /var/www/vulcan/public/uploads

# Keep only last 30 days of backups
find $BACKUP_DIR -type f -mtime +30 -delete
```

### Cron Job for Automated Backups

```bash
# Add to crontab
0 2 * * * /usr/local/bin/backup-vulcan.sh
```

## Performance Tuning

### PostgreSQL Optimization

Edit `/etc/postgresql/*/main/postgresql.conf`:

```ini
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
random_page_cost = 1.1
effective_io_concurrency = 200
min_wal_size = 1GB
max_wal_size = 4GB
```

### Application Tuning

```bash
# Set in .env.production
WEB_CONCURRENCY=2          # Number of Puma workers
RAILS_MAX_THREADS=5        # Threads per worker
DATABASE_POOL=25           # Database connection pool
```

## Troubleshooting

### Application Won't Start

```bash
# Check service status
sudo systemctl status vulcan

# Check logs
sudo journalctl -u vulcan -n 100

# Test configuration
cd /var/www/vulcan
bundle exec rails c
```

### Database Connection Issues

```bash
# Test connection
psql -U vulcan_user -h localhost -d vulcan_production

# Check PostgreSQL status
sudo systemctl status postgresql
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R vulcan:vulcan /var/www/vulcan

# Fix permissions
find /var/www/vulcan -type d -exec chmod 755 {} \;
find /var/www/vulcan -type f -exec chmod 644 {} \;
```

## Security Hardening

1. **Disable root SSH login**
2. **Configure fail2ban**
3. **Enable SELinux/AppArmor**
4. **Regular security updates**
5. **Implement database connection encryption**
6. **Use secrets management for credentials**

## Maintenance Commands

```bash
# Update application
cd /var/www/vulcan
git pull origin main
bundle install
pnpm install
bundle exec rails db:migrate
bundle exec rails assets:precompile
sudo systemctl restart vulcan

# Clear cache
bundle exec rails tmp:cache:clear

# Database maintenance
bundle exec rails db:analyze
bundle exec rails db:vacuum
```