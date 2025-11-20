#!/usr/bin/env bash
set -euo pipefail

# 支持交互或无交互模式：按 Enter 使用默认值；在无交互（pipe/CI）时使用环境变量或默认值
DEFAULT_USERNAME="deploy"
DEFAULT_PUBKEY=""

if [ -t 0 ]; then
  # 交互模式：提示用户，按 Enter 使用默认
  read -r -p "Username [${DEFAULT_USERNAME}]: " INPUT_USERNAME
  USERNAME=${INPUT_USERNAME:-$DEFAULT_USERNAME}
  echo "(可选) 将 SSH 公钥粘贴后按 Enter，或直接按 Enter 跳过："
  read -r -p "SSH public key: " INPUT_PUBKEY
  USER_SSH_PUBKEY=${INPUT_PUBKEY:-$DEFAULT_PUBKEY}
else
  # 非交互模式：优先使用环境变量 (如果预先导出)，否则使用默认
  USERNAME=${USERNAME:-$DEFAULT_USERNAME}
  USER_SSH_PUBKEY=${USER_SSH_PUBKEY:-$DEFAULT_PUBKEY}
fi

# 如果用户存在则跳过创建
if id "$USERNAME" &>/dev/null; then
  echo "用户 $USERNAME 已存在，跳过创建"
else
  useradd -m -s /bin/bash "$USERNAME"
  echo "创建用户 $USERNAME"
fi

# 生成随机密码并设置（如果未提供），长度 16 字节 base64
PASSWORD=${PASSWORD:-$(openssl rand -base64 12)}
echo "$USERNAME:$PASSWORD" | chpasswd

# 强制首次登录修改密码（可选）：将上面注释掉可取消强制修改
chage -d 0 "$USERNAME" || true

usermod -aG sudo "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USERNAME
chmod 440 /etc/sudoers.d/90-$USERNAME
echo "配置 sudo 无密码"

if [ -n "$USER_SSH_PUBKEY" ]; then
  su - "$USERNAME" -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
  # 追加公钥到 authorized_keys
  su - "$USERNAME" -c "echo '$USER_SSH_PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  echo "已为 $USERNAME 添加公钥"
else
  echo "未提供公钥，跳过 authorized_keys 配置。可使用 ssh-copy-id 或手动放入 /home/$USERNAME/.ssh/authorized_keys"
fi

echo "---- 账户信息（请保存） ----"
echo "用户名: $USERNAME"
echo "临时密码: $PASSWORD"
echo "提示: 已强制首次登录修改密码。请在第一次登录后立即运行 'passwd' 更改密码，或在 root 下使用 'chpasswd' 更新。"
echo "---------------------------"
