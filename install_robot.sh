#!/usr/bin/env bash
set -euo pipefail

# Конфигурация (можно переопределить через переменные окружения перед запуском)
DOTNET_PACKAGE="${DOTNET_PACKAGE:-dotnet-runtime-8.0}"   # варианты: dotnet-sdk-8.0 / dotnet-sdk-9.0
SERVICE_NAME="${SERVICE_NAME:-robot}"
APP_DIR="${APP_DIR:-/root/robot}"
ZIP_URL="${ZIP_URL:-https://123.timeweb.ru/robot.zip}"
ZIP_FILE="${ZIP_FILE:-/tmp/${SERVICE_NAME}.zip}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# sudo если скрипт не запущен от root
SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
fi

export DEBIAN_FRONTEND=noninteractive

echo "[2/6] Подключение Microsoft repo (Ubuntu 24.04)..."
$SUDO wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
$SUDO dpkg -i /tmp/packages-microsoft-prod.deb
$SUDO rm -f /tmp/packages-microsoft-prod.deb
$SUDO apt-get update -y

echo "[3/6] Установка .NET (${DOTNET_PACKAGE})..."
$SUDO apt-get install -y "${DOTNET_PACKAGE}"
if command -v dotnet >/dev/null 2>&1; then
  which dotnet || true
  dotnet --info || true
else
  echo "Внимание: dotnet не найден в PATH" >&2
fi

echo "[4/6] Правила UFW (без включения брандмауэра)..."
$SUDO ufw allow 22/tcp  || true
$SUDO ufw allow 443/tcp || true
$SUDO ufw allow 8000/tcp || true
$SUDO ufw allow 8001/tcp || true
$SUDO ufw allow 8003/tcp || true
$SUDO ufw allow 7001/tcp || true
$SUDO ufw allow 13402/tcp || true
$SUDO ufw allow 1209/udp  || true
$SUDO ufw allow 50001/tcp || true
$SUDO ufw allow 12345/tcp || true

echo "[6/6] Создание и запуск systemd-сервиса ${SERVICE_NAME}.service..."
$SUDO tee "${SERVICE_FILE}" >/dev/null <<EOF
[Unit]
Description=proxi Server .NET Service
After=network.target

[Service]
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/dotnet ${APP_DIR}/robot.dll
Restart=always
RestartSec=60
User=root
Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable "${SERVICE_NAME}.service"
$SUDO systemctl start "${SERVICE_NAME}.service"
$SUDO systemctl --no-pager --full status "${SERVICE_NAME}.service" | cat

echo "Готово."