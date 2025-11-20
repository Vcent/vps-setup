#!/usr/bin/env bash
set -euo pipefail

SSH_PORT=2222

apt update
apt install -y fail2ban

mkdir -p /etc/fail2ban/jail.d

cat > /etc/fail2ban/jail.d/sshd.conf <<'EOF'
[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

systemctl restart fail2ban
echo "fail2ban 已启用 (监控 ssh 端口 2222)"
