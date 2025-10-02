#!/bin/bash
# Bash Script to install Alertmanager on Ubuntu/Debian

set -e

# Variables
VERSION="0.27.0"   # تقدر تغيّر النسخة لو عايز
USER="alertmanager"

# Create user
sudo useradd --no-create-home --shell /bin/false $USER || true

# Download Alertmanager
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v${VERSION}/alertmanager-${VERSION}.linux-amd64.tar.gz
tar -xvf alertmanager-${VERSION}.linux-amd64.tar.gz
cd alertmanager-${VERSION}.linux-amd64

# Move binaries
sudo cp alertmanager amtool /usr/local/bin/

# Create directories
sudo mkdir -p /etc/alertmanager /var/lib/alertmanager
sudo cp alertmanager.yml /etc/alertmanager/alertmanager.yml

# Set ownership
sudo chown -R $USER:$USER /etc/alertmanager /var/lib/alertmanager

# Create systemd service
cat <<EOF | sudo tee /etc/systemd/system/alertmanager.service
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/alertmanager \\
  --config.file=/etc/alertmanager/alertmanager.yml \\
  --storage.path=/var/lib/alertmanager

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager

echo "✅ Alertmanager installation finished. Check status with: sudo systemctl status alertmanager"
