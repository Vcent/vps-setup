#!/usr/bin/env bash
set -euo pipefail

SSH_PORT=2222
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak.$(date +%s)"

cp -a "$SSHD_CONFIG" "$BACKUP"
echo "备份 sshd_config -> $BACKUP"

function set_or_replace() {
  local key="$1"; local val="$2"
  if grep -qE "^\s*${key}\s+" "$SSHD_CONFIG"; then
    sed -ri "s#^\s*(${key}\s+).*#\1${val}#g" "$SSHD_CONFIG"
  else
    echo "${key} ${val}" >> "$SSHD_CONFIG"
  fi
}

set_or_replace "Port" "$SSH_PORT"
set_or_replace "PermitRootLogin" "no"
set_or_replace "PasswordAuthentication" "no"
set_or_replace "PermitEmptyPasswords" "no"
set_or_replace "ChallengeResponseAuthentication" "no"

# 重启 ssh 服务
if systemctl list-units --type=service | grep -q sshd; then
  systemctl restart sshd
else
  systemctl restart ssh || service ssh restart
fi

echo "sshd 更新完成：Port=$SSH_PORT, 禁用 root 登录, 禁用密码登录"
echo "注意：请在新端口测试连接再断开当前 session。"
