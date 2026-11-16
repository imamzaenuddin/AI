#!/usr/bin/env bash
# ==============================================================================
# AI-V1 Host Independent Backup & Retention Script (Milik root di host)
# Menulis ke /var/backups/apps (di-mount :ro ke container Hermes).
#
# Retensi Standar AI-V1:
# - Dump SQL harian      : simpan 7 file terbaru per database
# - Arsip mingguan .tgz  : simpan maksimal 2 arsip terbaru per project
# ==============================================================================

set -euo pipefail

BACKUP_ROOT="/var/backups/apps"
DAILY_DB_DIR="${BACKUP_ROOT}/daily-db"
WEEKLY_WEB_DIR="${BACKUP_ROOT}/weekly-web"
PROJECT_ROOT="/home/project"
DATE_STAMP="$(date +%Y%m%d-%H%M%S)"
DAY_OF_WEEK="$(date +%u)" # 7 = Minggu

mkdir -p "${DAILY_DB_DIR}" "${WEEKLY_WEB_DIR}"
chmod 755 "${BACKUP_ROOT}" "${DAILY_DB_DIR}" "${WEEKLY_WEB_DIR}"

# 1. Backup Harian Semua Database Aplikasi (abaikan database sistem internal)
if command -v mysql >/dev/null 2>&1 && command -v mysqldump >/dev/null 2>&1; then
  DBS="$(mysql -N -e "SHOW DATABASES;" | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' || true)"
  for db in ${DBS}; do
    out_file="${DAILY_DB_DIR}/${db}-${DATE_STAMP}.sql.gz"
    mysqldump --single-transaction --routines --triggers "${db}" | gzip > "${out_file}"
    gzip -t "${out_file}"
    # Retensi: simpan 7 file terbaru per database
    ls -1t "${DAILY_DB_DIR}/${db}-"*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
  done
fi

# 2. Backup Mingguan File ProjectWeb (Minggu atau saat dipanggil --weekly)
if [[ "${DAY_OF_WEEK}" == "7" || "${1:-}" == "--weekly" ]]; then
  if [[ -d "${PROJECT_ROOT}" ]]; then
    for app_path in "${PROJECT_ROOT}"/*; do
      [[ -d "${app_path}" ]] || continue
      app="$(basename "${app_path}")"
      archive="${WEEKLY_WEB_DIR}/${app}-${DATE_STAMP}.tar.gz"
      tar --exclude='node_modules' --exclude='vendor' --exclude='.git/objects' \
          -czpf "${archive}" -C "${PROJECT_ROOT}" "${app}"
      # Retensi ketat AI-V1: maksimal 2 arsip mingguan per app di VPS
      ls -1t "${WEEKLY_WEB_DIR}/${app}-"*.tar.gz 2>/dev/null | tail -n +3 | xargs -r rm -f
    done
  fi
fi

echo "[$(date -Iseconds)] Backup host AI-V1 selesai."
