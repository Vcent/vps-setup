#!/usr/bin/env bash
set -euo pipefail

SSH_PORT=2222

apt update
apt install -y nftables

cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
table inet filter {
  chain input {
    type filter hook input priority 0;
    policy drop;

    iif lo accept
    ct state established,related accept

    # allow ssh on custom port
    tcp dport 2222 ct state new,established accept

    # allow tcp/udp 443
    tcp dport 443 ct state new,established accept
    udp dport 443 ct state new,established accept

    # allow icmp
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept

    # reject others
    reject
  }

  chain forward { type filter hook forward priority 0; policy drop; }
  chain output { type filter hook output priority 0; policy accept; }
}
EOF

systemctl enable --now nftables
nft -f /etc/nftables.conf || true

echo "nftables 已加载：只开放 SSH($SSH_PORT) 与 TCP/UDP 443；其他外网入口被拒绝。"
echo "确认云面板(安全组)也开放了相应端口。"
