#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

# Check the operating system and perform actions based on the detected distribution
os=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
if [[ $os == *"Ubuntu"* ]]; then
    package_manager="apt"
    echo "You are using Ubuntu distribution"
elif [[ $os == *"Red Hat"* || $os == *"Oracle Linux"* ]]; then
    echo "You are using RHEL or OL distribution"
    package_manager="yum"
    firewall-cmd --add-port=3000/tcp --permanent
    firewall-cmd --reload
else
    echo "Unsupported operating system"
    exit 1
fi

# Install required packages
$package_manager update -y
$package_manager install -y wget tar

# Prerequisites
adduser --no-create-home --system --shell /sbin/nologin prometheus
groupadd prometheus
mkdir /var/lib/prometheus /etc/prometheus/

# Download Prometheus
prometheus_version="2.36.2"

echo "Downloading Prometheus v$prometheus_version..."
wget "https://github.com/prometheus/prometheus/releases/download/v$prometheus_version/prometheus-$prometheus_version.linux-amd64.tar.gz" -P /tmp/

# Extract the downloaded tarball
echo "Extracting Prometheus tarball..."
tar xzf "/tmp/prometheus-$prometheus_version.linux-amd64.tar.gz" -C /tmp/

# Copy required files
echo "Copying Prometheus files..."
cp "/tmp/prometheus-$prometheus_version.linux-amd64/prometheus" "/usr/local/bin/"
cp "/tmp/prometheus-$prometheus_version.linux-amd64/promtool" "/usr/local/bin/"
cp -r "/tmp/prometheus-$prometheus_version.linux-amd64/consoles" "/etc/prometheus"
cp -r "/tmp/prometheus-$prometheus_version.linux-amd64/console_libraries" "/etc/prometheus/"
cp "/tmp/prometheus-$prometheus_version.linux-amd64/prometheus.yml" "/etc/prometheus/"

# Create Prometheus configuration file
echo "setting up the prometheus.yml config file"

cat << EOF > /etc/prometheus/prometheus.yml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).
# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093
# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"
# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label "job=<job_name>" to any timeseries scraped from this config.
  - job_name: "prometheus"
    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.
    static_configs:
      - targets: ["192.168.51.188:9090"]
EOF

# Changing ownership of prometheus directory
echo "changing ownership of some relevant directories"
chown prometheus:prometheus -R /etc/prometheus
chown prometheus:prometheus -R /var/lib/prometheus
chown prometheus:prometheus -R /usr/local/bin/prometheus

#create a systemd service file to manage the Prometheus service via systemd
echo "creating systemd service for prometheus"
cat << EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now prometheus

## Checking if prometheus.service is running
status=$(systemctl is-active prometheus)
# Print status message
if [[ $status == "active" ]]; then
    echo "Prometheus is running okay."
    curl localhost:9090
else
    echo "Prometheus is not running or in an unknown state."
fi



