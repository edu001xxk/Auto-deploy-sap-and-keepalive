#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# Telegram 配置
TG_TOKEN="7799976927:AAHY1DDudQzUTdwkvTAZ8OAy2zHvULCtTX0"
TG_ID="5848244735"

# 固定密码和 ngrok token
PASSWORD="XXK0327xxk"
NGROK_TOKEN="2lwIMI8sMQQnq8igBkMCUed5URe_AiBtwpzbGH2qYEdYyPMG"

# 检测是否具有 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请先运行 sudo -i 获取 root 权限后再执行此脚本${RESET}" && exit 1

echo -e "${GREEN}===== 开始设置 SSH 和 Ngrok 隧道 =====${RESET}"

echo -e "${YELLOW}[1/5] 终止现有 SSH 进程...${RESET}"
lsof -i:22 | awk '/IPv4/{print $2}' | xargs kill -9 2>/dev/null || true

echo -e "${YELLOW}[2/5] 配置 SSH 服务，允许 root 登录和密码认证...${RESET}"
echo -e '\nPermitRootLogin yes\nPasswordAuthentication yes' >> /etc/ssh/sshd_config

echo -e "${YELLOW}[3/5] 设置 root 用户密码...${RESET}"
echo root:$PASSWORD | chpasswd root

echo -e "${YELLOW}[4/5] 启用 SSH 和 Docker 服务...${RESET}"
systemctl unmask ssh docker docker.socket containerd
systemctl start ssh docker docker.socket containerd

echo -e "${YELLOW}[5/5] 下载并运行 Ngrok...${RESET}"
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -qO- | tar -xz -C /usr/local/bin
pkill -f "ngrok tcp 22" >/dev/null 2>&1 || true
nohup /usr/local/bin/ngrok tcp 22 --authtoken=${NGROK_TOKEN} >/dev/null 2>&1 &

sleep 5
echo -e "${YELLOW}获取 ngrok 隧道信息...${RESET}"
NGROK_INFO=$(curl -s http://localhost:4040/api/tunnels)

grep -q "Your account is limited to 1 simultaneous ngrok agent sessions." <<< $NGROK_INFO && echo -e "${RED}错误: 您的 ngrok 账户限制了同时只能有一个 ngrok 代理会话，请检查您的 ngrok 设置。${RESET}" && exit 1
! grep -q "public_url" <<< $NGROK_INFO && echo -e "${RED}错误: 无法获取 ngrok 隧道信息，请检查 ngrok 是否正常运行。${RESET}" && exit 1

NGROK_URL=$(sed 's#.*tcp://\([^"]\+\)".*#\1#' <<< $NGROK_INFO)
NGROK_HOST=$(cut -d: -f1 <<< $NGROK_URL)
NGROK_PORT=$(cut -d: -f2 <<< $NGROK_URL)

# 显示信息
echo -e "${GREEN}===== 设置完成 =====${RESET}"
echo -e "${GREEN}SSH 地址: ${RESET}$NGROK_HOST"
echo -e "${GREEN}SSH 端口: ${RESET}$NGROK_PORT"
echo -e "${GREEN}SSH 用户: ${RESET}root"
echo -e "${GREEN}SSH 密码: ${RESET}$PASSWORD"

# 发送到 Telegram
MESSAGE="SSH 隧道信息已生成:
Host: $NGROK_HOST
Port: $NGROK_PORT
User: root
Password: $PASSWORD"
curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d chat_id="${TG_ID}" \
  -d text="$MESSAGE" >/dev/null

echo -e "${YELLOW}SSH 信息已发送到 Telegram${RESET}"