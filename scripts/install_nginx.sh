#!/bin/bash
set -euo pipefail

DOMAIN="just.hosting"
SSL_DIR="/etc/ssl/custom"
SITE="/etc/nginx/sites-available/just_hosting"
LINK="/etc/nginx/sites-enabled/just_hosting"
RENEW_SCRIPT="/usr/local/bin/renew-selfcerts.sh"

apt update
apt install -y nginx openssl

mkdir -p "$SSL_DIR"
chmod 700 "$SSL_DIR"

CERT_DAYS=90
openssl req -newkey rsa:4096 -nodes -keyout "$SSL_DIR/$DOMAIN.key" \
  -x509 -days $CERT_DAYS -out "$SSL_DIR/$DOMAIN.crt" -subj "/CN=$DOMAIN" >/dev/null

chmod 600 "$SSL_DIR/$DOMAIN.key"
chmod 644 "$SSL_DIR/$DOMAIN.crt"

cat > /var/www/just_hosting_index.html <<'HTML'
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>just.hosting</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background-color: #f8f9fa;
            color: #333;
            line-height: 1.6;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 1em;
            font-weight: 700;
        }
        p {
            font-size: 1.1em;
            margin-bottom: 2em;
        }
        .footer {
            margin-top: 3em;
            font-size: 0.9em;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>just.hosting</h1>
        <p>Minimal landing page — served by nginx</p>
        <p>Your web server is running correctly.</p>
        <div class="footer">
            <p>Just hosting, nothing more.</p>
        </div>
    </div>
</body>
</html>
HTML

# Use single quotes around NGINX to prevent shell expansion of variables
cat > "$SITE" <<'NGINX'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass https://127.0.0.1:8443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_ssl_verify off;
    }
}

server {
    listen 127.0.0.1:8443 ssl;
    server_name localhost;

    ssl_certificate     /etc/ssl/custom/just.hosting.crt;
    ssl_certificate_key /etc/ssl/custom/just.hosting.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /var/www;
    index just_hosting_index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

ln -sf "$SITE" "$LINK"
nginx -t
systemctl restart nginx
systemctl enable nginx

cat > "$RENEW_SCRIPT" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
SSL_DIR="/etc/ssl/custom"
DOMAIN="just.hosting"
CERT_DAYS=90

openssl req -newkey rsa:4096 -nodes -keyout "$SSL_DIR/$DOMAIN.key.tmp" \
  -x509 -days $CERT_DAYS -out "$SSL_DIR/$DOMAIN.crt.tmp" -subj "/CN=$DOMAIN" >/dev/null

mv "$SSL_DIR/$DOMAIN.key.tmp" "$SSL_DIR/$DOMAIN.key"
mv "$SSL_DIR/$DOMAIN.crt.tmp" "$SSL_DIR/$DOMAIN.crt"
chmod 600 "$SSL_DIR/$DOMAIN.key"
chmod 644 "$SSL_DIR/$DOMAIN.crt"

systemctl reload nginx || true
systemctl try-restart xray.service || true
echo "自签证书已更新并重载相关服务：$(date -Iseconds)"
SH

chmod +x "$RENEW_SCRIPT"

cat > /etc/systemd/system/selfcert-renew.service <<'SERVICE'
[Unit]
Description=Renew self-signed certificates for local services

[Service]
Type=oneshot
ExecStart=/usr/local/bin/renew-selfcerts.sh
SERVICE

cat > /etc/systemd/system/selfcert-renew.timer <<'TIMER'
[Unit]
Description=Run selfcert renewal every 30 days

[Timer]
OnBootSec=1min
OnUnitActiveSec=30d
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now selfcert-renew.timer

echo "nginx 安装并配置完成：127.0.0.1:8443 提供 HTTPS，80 代理到 8443，自签证书自动续期已设置。"
