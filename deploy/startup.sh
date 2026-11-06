#!/bin/bash
# VM boot script used by instance templates that CI creates.
# Pulls DB settings from Secret Manager with the VM's own service account
# (no secrets in instance metadata), writes the app's env file, starts the app.
# Keep in sync with tf-gcp-infra/scripts/startup.sh.tftpl.
set -euo pipefail

PROJECT_ID="$(curl -sf -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/project/project-id)"

get_secret() {
  gcloud secrets versions access latest --secret="$1" --project="$PROJECT_ID"
}

DB_IP="$(get_secret db_ip)"
DB_NAME="$(get_secret db_name)"
DB_USER="$(get_secret db_username)"
DB_PASS="$(get_secret db_password)"

umask 077
cat > /opt/.env <<ENV
DATABASE_URL=jdbc:mysql://$DB_IP:3306/$DB_NAME?createDatabaseIfNotExist=true
DATABASE_USERNAME=$DB_USER
DATABASE_PASSWORD=$DB_PASS
ENV
chown csye6225:csye6225 /opt/.env

setenforce 0 || true
systemctl daemon-reload
systemctl restart csye6225.service
