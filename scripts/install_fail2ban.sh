#!/bin/bash
set -euo pipefail

SSH_PORT=2222

apt update
apt install -y fail2ban

# 确保auth.log文件存在
touch /var/log/auth.log
echo "已创建SSH日志文件: /var/log/auth.log"

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

# 重启Fail2Ban服务
systemctl restart fail2ban
echo "fail2ban 已启用 (监控 ssh 端口 2222)"
