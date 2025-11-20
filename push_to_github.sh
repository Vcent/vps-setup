#!/usr/bin/env bash
set -euo pipefail

# push_to_github.sh
# 交互式辅助脚本：检查敏感文件 -> 初始化 git -> 可选用 gh 创建 repo -> push
# 运行示例：bash push_to_github.sh

WORKDIR=${1:-$(pwd)}
cd "$WORKDIR"

echo "工作目录: $WORKDIR"

# 检查是否有 Git 配置
if ! command -v git >/dev/null 2>&1; then
  echo "错误: git 未安装。请先运行：sudo apt install -y git （或在 macOS 上使用 brew install git）"
  exit 1
fi

# 扫描敏感文件（快速）
echo "扫描敏感文件/私钥..."
FOUND_KEYS=$(grep -R --line-number -E "BEGIN .*PRIVATE KEY|PRIVATE KEY|BEGIN RSA PRIVATE KEY|BEGIN ED25519 PRIVATE KEY|-----BEGIN OPENSSH PRIVATE KEY-----" . || true)
FOUND_PEMS=$(ls -1 | grep -E "\.(pem|key)$" || true)
FOUND_SECRETS=$(grep -R --line-number -E "password|secret|TOKEN|API_KEY|PRIVATE_KEY|ACCESS_KEY|SECRET_KEY" . || true)

if [ -n "$FOUND_KEYS" ] || [ -n "$FOUND_PEMS" ] || [ -n "$FOUND_SECRETS" ]; then
  echo "检测到以下疑似敏感内容/文件，请手动确认是否需要从仓库排除："
  echo "---- 私钥相关匹配 ----"
  echo "$FOUND_KEYS"
  echo "---- 扩展名匹配 (.pem/.key) 在当前目录 ----"
  echo "$FOUND_PEMS"
  echo "---- 可能包含 secret 的文本匹配 ----"
  echo "$FOUND_SECRETS"
  echo
  read -r -p "是否继续并把所有文件加入 git（不安全）？(yes/NO) " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "已取消。请移除或 .gitignore 敏感文件后重试。"
    exit 1
  fi
else
  echo "未发现明显敏感文件，继续..."
fi

# 让用户确认 repo 名称或完整 remote URL
read -r -p "请输入 GitHub 仓库远程 URL (例如 git@github.com:yourname/vps-setup.git)，或直接输入仓库名 (yourname/vps-setup) 来让 gh 创建：" REMOTE

# 如果输入看起来像 owner/repo，则尝试使用 gh 创建
USE_GH_CREATE=0
if [[ "$REMOTE" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  if command -v gh >/dev/null 2>&1; then
    read -r -p "检测到仓库名形式 '$REMOTE'，是否使用 gh 创建远程仓库并设置为 private? (yes/NO) " GHCONF
    if [ "$GHCONF" = "yes" ]; then
      USE_GH_CREATE=1
    fi
  else
    echo "提示：要自动创建仓库，请安装 gh (brew install gh)，或在 GitHub Web UI 手动创建，并传入 remote URL。"
  fi
fi

# 初始化 git 仓库
if [ ! -d .git ]; then
  git init
  echo "已初始化 git 仓库"
else
  echo "仓库已存在 .git，跳过 git init"
fi

# 保证 scripts 可执行标志已设置
if [ -d scripts ]; then
  chmod +x scripts/*.sh || true
  git update-index --chmod=+x scripts/*.sh || true
fi

# 添加并提交
git add .
read -r -p "输入 commit message（回车使用默认 'Add vps setup scripts (MVP)'): " COMMIT_MSG
COMMIT_MSG=${COMMIT_MSG:-"Add vps setup scripts (MVP)"}

git commit -m "$COMMIT_MSG" || echo "无变更要提交或提交失败"

# 创建远程并 push
if [ $USE_GH_CREATE -eq 1 ]; then
  echo "使用 gh 创建仓库: $REMOTE"
  gh repo create "$REMOTE" --private --confirm || { echo "gh 创建失败，改为手动创建或提供 remote URL"; exit 1; }
  git remote add origin "git@github.com:$REMOTE.git" 2>/dev/null || true
  git push -u origin main || git push -u origin master || true
  echo "已 push 到 git@github.com:$REMOTE.git"
else
  # 假设用户输入完整 remote URL
  if [[ "$REMOTE" =~ ^git@|^https:// ]]; then
    git remote add origin "$REMOTE" 2>/dev/null || git remote set-url origin "$REMOTE"
    git branch -M main 2>/dev/null || true
    echo "开始推送到 $REMOTE ..."
    git push -u origin main || git push -u origin master || { echo "推送失败，请检查 SSH Key 或远程 URL（错误信息请查看 git 输出）"; exit 1; }
    echo "推送完成。"
  else
    echo "输入既不是 owner/repo 也不是完整 remote URL。请重试并输入例如 git@github.com:yourname/vps-setup.git 或 yourname/vps-setup 。"
    exit 1
  fi
fi

echo "完成：仓库已推送到远程。请在 GitHub 页面确认文件。"
