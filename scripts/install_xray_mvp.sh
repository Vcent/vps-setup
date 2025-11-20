#!/usr/bin/env bash
set -euo pipefail

DOMAIN="just.hosting"
XRAY_DIR="/etc/xray"
CONFIG="$XRAY_DIR/config.json"
UUID="$(cat /proc/sys/kernel/random/uuid)"

apt update
apt install -y curl

# 下载并运行官方安装脚本（会把 xray 安装到 /usr/local/bin/xray）
bash -c "$(curl -sL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" install

mkdir -p "$XRAY_DIR"
cat > "$CONFIG" <<JSON
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$UUID" }
        ],
        "decryption": "none",
        "fallbacks": [
          { "dest": 8443 }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": ["h2","http/1.1"],
          "certificates": [
            {
              "certificateFile": "/etc/ssl/custom/$DOMAIN.crt",
              "keyFile": "/etc/ssl/custom/$DOMAIN.key"
            }
          ],
          "serverName": "$DOMAIN"
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
JSON

# 如果安装脚本没有自动创建 systemd unit，创建一个
if ! systemctl list-unit-files | grep -q "^xray.service"; then
  cat > /etc/systemd/system/xray.service <<'SERVICE'
[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE
fi

mkdir -p /var/log/xray
chown -R root:root "$XRAY_DIR"
systemctl daemon-reload
systemctl enable --now xray.service

echo "Xray 已安装（MVP 配置），UUID=$UUID"
echo "注意：此为 MVP（仅 vless+xtls），如需 reality/tuic 请在确认并测试 MVP 后逐步添加。"
