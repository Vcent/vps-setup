# vps-setup (MVP)

目的：一键完成 VPS 的基础安全与服务部署（nginx + xray MVP）。

目录结构：
- README.md                — 使用说明、运行顺序、注意事项
- .gitignore
- scripts/
  - create_user.sh
  - configure_sshd.sh
  - install_fail2ban.sh
  - firewall.sh
  - enable_bbr.sh
  - install_nginx.sh
  - install_xray_mvp.sh

运行顺序（在 VPS 上，以 root 或 sudo）：
1. scripts/create_user.sh
2. scripts/configure_sshd.sh
3. scripts/firewall.sh
4. scripts/enable_bbr.sh
5. scripts/install_fail2ban.sh
6. scripts/install_nginx.sh
7. scripts/install_xray_mvp.sh

准备与推送（本地 macOS）：
```bash
mkdir -p ~/vps-setup && cd ~/vps-setup
# 将 /tmp/vps-setup 下的文件复制到此目录，或直接把该目录作为 repo
git init
git add .
git commit -m "Add vps setup scripts (MVP)"
# 在 GitHub 上创建 repo 并添加 remote
git remote add origin git@github.com:yourname/vps-setup.git
git branch -M main
git push -u origin main
```

在 VPS 上获取并执行：
```bash
apt update && apt install -y git
cd /opt
git clone git@github.com:yourname/vps-setup.git
cd vps-setup/scripts
# 编辑脚本顶部变量后逐个运行
sudo bash create_user.sh
sudo bash configure_sshd.sh
# 在另一台终端测试 ssh -p 2222 ...
sudo bash firewall.sh
sudo bash enable_bbr.sh
sudo bash install_fail2ban.sh
sudo bash install_nginx.sh
sudo bash install_xray_mvp.sh
```

调试要点：
- nftables: `sudo nft list ruleset`
- nginx: `sudo systemctl status nginx`，`curl -k https://127.0.0.1:8443/`
- xray: `sudo systemctl status xray`，查看 `/var/log/xray/*`

注意：`create_user.sh` 的行为说明
- 脚本在交互模式下会提示输入用户名与公钥，按 Enter 使用默认（用户名默认 `deploy`）。
- 在非交互环境（比如 CI / pipe）或按 Enter 跳过时，脚本会自动为用户生成一个随机密码并设置该密码。
- 脚本会在输出中显示临时密码，并会强制首次登录修改密码（可按需取消）。
- 如果你计划立即禁用 SSH 密码登录（脚本 `configure_sshd.sh` 会设置 PasswordAuthentication no），请确保你已把公钥写入目标用户的 `~/.ssh/authorized_keys`，否则将无法通过 SSH 使用密码登录。

安全建议：
- 先在测试环境验证后再在生产启用 reality/tuic
- 若有实际域名并可解析，推荐使用 Let\'s Encrypt 替换自签证书
- 在更改 sshd 和防火墙前务必保持至少一条可用连接
