#!/bin/bash
set -euo pipefail

export HOME=/root

# System update and install prerequisites
dnf clean all
dnf update -y
dnf install -y git
%{ if enable_cloudwatch_agent }
dnf install -y amazon-cloudwatch-agent
%{ endif }

# ============================================================
# Create dedicated hermes user
# Ref: https://hermes-agent.nousresearch.com/docs/getting-started/installation#non-sudo--system-service-user-installs
# ============================================================
useradd -r -m -s /bin/bash hermes || true

# Install Playwright system deps (requires root, one-time)
dnf install -y nss atk at-spi2-core cups-libs libdrm libxkbcommon mesa-libgbm pango cairo alsa-lib || true

# ============================================================
# Install Hermes Agent as hermes user (per-user layout)
# Code: ~/.hermes/hermes-agent/
# Command: ~/.local/bin/hermes
# Data: ~/.hermes/
# ============================================================
su - hermes -c 'curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup --skip-browser'

# ============================================================
# Configure Hermes Agent
# Ref: https://hermes-agent.nousresearch.com/docs/guides/aws-bedrock#configuration
# Ref: https://hermes-agent.nousresearch.com/docs/reference/environment-variables/
# ============================================================

# Retrieve secrets from SSM (as root, has IAM role access)
TELEGRAM_TOKEN=$(aws ssm get-parameter \
  --name "/${project_name}/telegram-bot-token" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region ${aws_region})

TELEGRAM_ALLOWED_USERS=$(aws ssm get-parameter \
  --name "/${project_name}/telegram-allowed-users" \
  --query "Parameter.Value" \
  --output text \
  --region ${aws_region} 2>/dev/null || echo "")

# Write .env (overwrite installer default)
printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_TOKEN" > /home/hermes/.hermes/.env
if [ -n "$TELEGRAM_ALLOWED_USERS" ]; then
  printf 'TELEGRAM_ALLOWED_USERS=%s\n' "$TELEGRAM_ALLOWED_USERS" >> /home/hermes/.hermes/.env
fi
chmod 600 /home/hermes/.hermes/.env
chown hermes:hermes /home/hermes/.hermes/.env

# Write config.yaml (overwrite installer default)
printf 'model:\n  default: "%s"\n  provider: "bedrock"\n\nbedrock:\n  region: "%s"\n' \
  "${bedrock_model_id}" "${aws_region}" > /home/hermes/.hermes/config.yaml

# Ensure all .hermes files are owned by hermes user
chown -R hermes:hermes /home/hermes/.hermes

%{ if enable_cloudwatch_agent }
# ============================================================
# CloudWatch Agent
# ============================================================
cat > /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent.json << 'CWEOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "HermesAgent",
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "totalcpu": true,
        "measurement": ["usage_active", "usage_idle", "usage_iowait"]
      },
      "mem": {
        "measurement": ["used_percent", "available_percent", "total", "used"]
      },
      "disk": {
        "resources": ["/"],
        "measurement": ["used_percent", "free", "total"],
        "ignore_file_system_types": ["sysfs", "devtmpfs", "tmpfs", "overlay"]
      },
      "swap": {
        "measurement": ["used_percent"]
      }
    }
  }
}
CWEOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent.json -s
%{ endif }

# ============================================================
# Install and start Hermes Gateway as systemd service
# - Must run as root to write /etc/systemd/system/
# - --run-as-user hermes: service runs as hermes user
# - HERMES_HOME points to hermes user's data directory
# Ref: https://hermes-agent.nousresearch.com/docs/getting-started/installation#non-sudo--system-service-user-installs
# ============================================================
export HERMES_HOME=/home/hermes/.hermes
printf 'n\ny\n' | /home/hermes/.local/bin/hermes gateway install --system --run-as-user hermes

# Fix ownership after gateway install (install runs as root, creates files owned by root)
chown -R hermes:hermes /home/hermes/.hermes

systemctl start hermes-gateway
