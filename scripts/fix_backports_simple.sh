#!/usr/bin/env bash
set -euo pipefail

# fix_backports_simple.sh
# 备份并注释掉包含 bullseye-backports 的行，然后尝试 apt update（若失败尝试 IPv4），失败时恢复备份。
# 用法：sudo bash scripts/fix_backports_simple.sh

BACKPORTS_FILE=/etc/apt/sources.list.d/backports.list
TIMESTAMP=$(date +%Y%m%dT%H%M%S)
BACKUP="${BACKPORTS_FILE}.bak.${TIMESTAMP}"

if [ $(id -u) -ne 0 ]; then
  echo "请以 root 或 sudo 运行此脚本。" >&2
  exit 2
fi

if [ ! -f "$BACKPORTS_FILE" ]; then
  echo "未找到 $BACKPORTS_FILE。请确认该文件路径或手动检查 /etc/apt/sources.list.d/ 下的文件。" >&2
  exit 1
fi

echo "备份 $BACKPORTS_FILE -> $BACKUP"
cp -a "$BACKPORTS_FILE" "$BACKUP"

echo "注释包含 'bullseye-backports' 的行（保留备份以便回滚）..."
sed -i.bak -E 's@^[[:space:]]*(deb[[:space:]]+.*bullseye-backports.*)@# \\1@' "$BACKPORTS_FILE"

echo "变更后的文件内容："
sed -n '1,200p' "$BACKPORTS_FILE" || true

echo
echo "现在尝试运行 apt update（普通方式）..."
set +e
apt update
RC=$?
set -e
if [ $RC -eq 0 ]; then
  echo "apt update 成功，问题已解决。"
  exit 0
fi

echo "普通 apt update 失败，尝试使用 IPv4 强制更新..."
set +e
apt -o Acquire::ForceIPv4=true update
RC2=$?
set -e
if [ $RC2 -eq 0 ]; then
  echo "apt update (IPv4) 成功，问题已解决（可能是 IPv6 导致的镜像问题）。"
  exit 0
fi

echo "两次 apt update 均失败，恢复原始文件并退出（请检查网络/镜像源）。" >&2
mv "$BACKUP" "$BACKPORTS_FILE"
echo "已恢复原始文件： $BACKPORTS_FILE"
exit 1
