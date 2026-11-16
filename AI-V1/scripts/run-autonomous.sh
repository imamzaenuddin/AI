#!/usr/bin/env bash
# ==============================================================================
# AI-V1 Autonomous Background Runner & Sync Script
# Menjalankan sinkronisasi repo AI-V1, pembaruan skrip dashboard/model-check,
# perbaikan runtime (php8.3-sqlite3, permission, model probe), dan mencatat
# seluruh progres secara real-time ke /var/log/aiv1-autonomous.log.
#
# Aman dijalankan dengan nohup sehingga laptop bisa ditutup/shutdown:
#   sudo bash /opt/AI-V1/AI-V1/scripts/run-autonomous.sh --bg
# Pantau progres real-time di CLI VPS:
#   tail -f /var/log/aiv1-autonomous.log
#   bash /opt/AI-V1/AI-V1/scripts/monitor-cli.sh --watch
# ==============================================================================

set -euo pipefail

LOG_FILE="/var/log/aiv1-autonomous.log"
PID_FILE="/var/run/aiv1-autonomous.pid"

if [[ "${1:-}" == "--bg" ]]; then
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Jalankan dengan sudo." >&2
    exit 1
  fi
  nohup bash "$0" --worker > "${LOG_FILE}" 2>&1 < /dev/null &
  echo $! > "${PID_FILE}"
  echo "Berjalan otonom di background (PID: $(cat "${PID_FILE}"))."
  echo "Pantau log real-time : tail -f ${LOG_FILE}"
  echo "Pantau status CLI    : bash /opt/AI-V1/AI-V1/scripts/monitor-cli.sh --watch"
  exit 0
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "=== AI-V1 AUTONOMOUS SYNC & VERIFY START ==="

log "[1/5] Pull update terbaru repo /opt/AI-V1..."
if [[ -d /opt/AI-V1/.git ]]; then
  git -C /opt/AI-V1 pull --ff-only
fi

log "[2/5] Pastikan ekstensi PHP 8.3 sqlite3 terpasang untuk sim-pt..."
if ! php -m 2>/dev/null | grep -qi "pdo_sqlite"; then
  DEBIAN_FRONTEND=noninteractive apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y php8.3-sqlite3
  systemctl restart php8.3-fpm
fi

log "[3/5] Sinkronkan vps-dashboard & check_models.py terbaru..."
cp /opt/AI-V1/AI-V1/vps-dashboard/server.py /opt/vps-dashboard/server.py
cp /opt/AI-V1/AI-V1/vps-dashboard/static/index.html /opt/vps-dashboard/static/index.html
chmod +x /opt/vps-dashboard/server.py
systemctl restart vps-monitor.service

cp /opt/AI-V1/AI-V1/scripts/check_models.py /opt/hermes/data/scripts/check_models.py
chown 10001:10001 /opt/hermes/data/scripts/check_models.py

log "[4/5] Jalankan probe model AI semua agent (UID 10001)..."
if docker ps --format '{{.Names}}' | grep -qx 'hermes-gateway'; then
  docker exec -u 10001 hermes-gateway python3 /opt/data/scripts/check_models.py --discover-free
fi

log "[5/5] Bersihkan folder staging restore jika masih ada & tampilkan ringkasan..."
rm -rf /home/ubuntu/restore-bundle /tmp/hermes-import
bash /opt/AI-V1/AI-V1/scripts/monitor-cli.sh

log "=== AI-V1 AUTONOMOUS SYNC & VERIFY DONE ==="
