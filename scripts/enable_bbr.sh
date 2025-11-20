#!/usr/bin/env bash
set -euo pipefail

cat > /etc/sysctl.d/99-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sysctl --system

modprobe tcp_bbr || true

echo "已写入 /etc/sysctl.d/99-bbr.conf 并尝试加载 bbr，若内核不支持请升级内核并重启。"
