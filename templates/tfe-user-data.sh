#!/usr/bin/env bash
set -euo pipefail

# Log all output
exec > >(tee /var/log/tfe-user-data.log) 2>&1
echo "=== TFE FDO Bootstrap - $(date) ==="

#------------------------------------------------------
# Mount Docker data volume
#------------------------------------------------------
if [[ -b /dev/xvdb ]] && ! blkid /dev/xvdb; then
  mkfs.xfs /dev/xvdb
fi
mkdir -p /var/lib/docker
if ! mountpoint -q /var/lib/docker; then
  mount /dev/xvdb /var/lib/docker
  echo '/dev/xvdb /var/lib/docker xfs defaults,nofail 0 2' >> /etc/fstab
fi

#------------------------------------------------------
# Install Docker
#------------------------------------------------------
dnf install -y docker
systemctl enable docker
systemctl start docker

#------------------------------------------------------
# Create TFE directories
#------------------------------------------------------
mkdir -p /etc/tfe /var/lib/tfe

#------------------------------------------------------
# Write TFE configuration
#------------------------------------------------------
cat > /etc/tfe/tfe.env <<'TFEENV'
# --- Core ---
TFE_HOSTNAME=${tfe_hostname}
TFE_LICENSE=${tfe_license}
TFE_ENCRYPTION_PASSWORD=${tfe_encryption_password}
TFE_OPERATIONAL_MODE=active-active

# --- TLS ---
TFE_TLS_CERT_FILE=/etc/tfe/tls/cert.pem
TFE_TLS_KEY_FILE=/etc/tfe/tls/key.pem
TFE_TLS_CA_BUNDLE_FILE=/etc/tfe/tls/ca.pem

# --- Database ---
TFE_DATABASE_HOST=${db_host}
TFE_DATABASE_PORT=${db_port}
TFE_DATABASE_NAME=${db_name}
TFE_DATABASE_USER=${db_username}
TFE_DATABASE_PASSWORD=${db_password}
TFE_DATABASE_PARAMETERS=sslmode=require

# --- Redis ---
TFE_REDIS_HOST=${redis_host}
TFE_REDIS_PORT=${redis_port}
TFE_REDIS_PASSWORD=${redis_auth_token}
TFE_REDIS_USE_TLS=true
TFE_REDIS_USE_AUTH=true

# --- Object Storage ---
TFE_OBJECT_STORAGE_TYPE=s3
TFE_OBJECT_STORAGE_S3_BUCKET=${s3_bucket}
TFE_OBJECT_STORAGE_S3_REGION=${s3_region}
TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE=true
TFE_OBJECT_STORAGE_S3_SERVER_SIDE_ENCRYPTION=aws:kms
TFE_OBJECT_STORAGE_S3_SERVER_SIDE_ENCRYPTION_KMS_KEY_ID=${kms_key_arn}

# --- Vault Cluster (Active/Active) ---
TFE_VAULT_CLUSTER_ADDRESS=https://HOSTNAME:8201
TFE_VAULT_DISABLE_MLOCK=true

# --- HTTP ---
TFE_HTTP_PORT=8080
TFE_HTTPS_PORT=8443

# --- Logging ---
TFE_LOG_FORWARDING_ENABLED=true
TFE_LOG_FORWARDING_CONFIG_PATH=/etc/tfe/fluent-bit.conf

# --- Run Pipeline ---
TFE_RUN_PIPELINE_DOCKER_NETWORK=tfe
TFE_IACT_SUBNETS=0.0.0.0/0
TFEENV

#------------------------------------------------------
# Retrieve TLS certificate from ACM via metadata
# For FDO, we generate a self-signed cert for the
# container and let the ALB handle real TLS termination
#------------------------------------------------------
mkdir -p /etc/tfe/tls

openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout /etc/tfe/tls/key.pem \
  -out /etc/tfe/tls/cert.pem \
  -sha256 -days 365 \
  -subj "/CN=${tfe_hostname}"

cp /etc/tfe/tls/cert.pem /etc/tfe/tls/ca.pem

#------------------------------------------------------
# Fluent Bit configuration for CloudWatch
#------------------------------------------------------
cat > /etc/tfe/fluent-bit.conf <<'FBCONF'
[OUTPUT]
    Name              cloudwatch_logs
    Match             *
    region            ${s3_region}
    log_group_name    ${log_group}
    log_stream_prefix tfe-
    auto_create_group false
FBCONF

#------------------------------------------------------
# Docker compose for TFE
#------------------------------------------------------
cat > /etc/tfe/docker-compose.yaml <<'COMPOSE'
name: tfe
services:
  tfe:
    image: ${tfe_image}
    restart: unless-stopped
    env_file:
      - /etc/tfe/tfe.env
    ports:
      - "443:8443"
      - "8201:8201"
    volumes:
      - tfe-data:/var/lib/tfe
      - /etc/tfe/tls:/etc/tfe/tls:ro
      - /etc/tfe/fluent-bit.conf:/etc/tfe/fluent-bit.conf:ro
      - /var/run/docker.sock:/var/run/docker.sock
    cap_add:
      - IPC_LOCK
    networks:
      - tfe

networks:
  tfe:
    driver: bridge

volumes:
  tfe-data:
COMPOSE

#------------------------------------------------------
# Replace HOSTNAME placeholder in Vault cluster address
#------------------------------------------------------
INSTANCE_IP=$(hostname -I | awk '{print $1}')
sed -i "s|TFE_VAULT_CLUSTER_ADDRESS=https://HOSTNAME:8201|TFE_VAULT_CLUSTER_ADDRESS=https://$INSTANCE_IP:8201|" /etc/tfe/tfe.env

#------------------------------------------------------
# Pull and start TFE
#------------------------------------------------------
cd /etc/tfe
docker compose up -d

echo "=== TFE FDO Bootstrap Complete - $(date) ==="
