#!/usr/bin/env bash
# ==============================================================================
# AI-V1 PM-Only Encrypted Credentials Vault (AES-256-CBC + PBKDF2 600k iter)
# Catatan resource penting (username, password, API key, token) dienkripsi
# dengan Master Password dan HANYA boleh diakses oleh Admin & pm-lead (00-pm-coordinator).
#
# Lokasi Vault Runtime:
#   Host      : /opt/hermes/data/credentials/pm-vault.enc (chmod 600, 10001:10001)
#   Container : /opt/data/credentials/pm-vault.enc
#
# Penggunaan:
#   bash pm-vault.sh init     # Buat vault terenkripsi baru dari template
#   bash pm-vault.sh read     # Baca isi vault (minta password)
#   bash pm-vault.sh edit     # Edit vault di /dev/shm lalu enkripsi ulang
#   bash pm-vault.sh verify   # Cek permission & kepemilikan vault tanpa membuka isi
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TEMPLATE="${SCRIPT_DIR}/../agents/00-pm-coordinator/vault.example.md"

if [[ -d "/opt/data/credentials" ]]; then
  VAULT_DIR="/opt/data/credentials"
elif [[ -d "/opt/hermes/data/credentials" ]]; then
  VAULT_DIR="/opt/hermes/data/credentials"
else
  VAULT_DIR="${PM_VAULT_DIR:-/opt/hermes/data/credentials}"
fi

VAULT_FILE="${PM_VAULT_FILE:-${VAULT_DIR}/pm-vault.enc}"
TMP_DIR="/dev/shm"
[[ -d "${TMP_DIR}" && -w "${TMP_DIR}" ]] || TMP_DIR="/tmp"

secure_delete() {
  local f="$1"
  if [[ -f "${f}" ]]; then
    if command -v shred >/dev/null 2>&1; then
      shred -u -z "${f}" 2>/dev/null || rm -f "${f}"
    else
      rm -f "${f}"
    fi
  fi
}

require_openssl() {
  if ! command -v openssl >/dev/null 2>&1; then
    echo "Error: openssl tidak terpasang." >&2
    exit 1
  fi
}

cmd_init() {
  require_openssl
  if [[ -f "${VAULT_FILE}" ]]; then
    echo "Vault sudah ada di ${VAULT_FILE}. Gunakan 'edit' atau 'read'."
    exit 1
  fi
  mkdir -p "$(dirname "${VAULT_FILE}")"
  chmod 700 "$(dirname "${VAULT_FILE}")"

  local tmp_plain
  tmp_plain="$(mktemp "${TMP_DIR}/pm-vault.XXXXXX")"
  chmod 600 "${tmp_plain}"
  trap 'secure_delete "'"${tmp_plain}"'"' EXIT

  if [[ -f "${DEFAULT_TEMPLATE}" ]]; then
    cp "${DEFAULT_TEMPLATE}" "${tmp_plain}"
  else
    echo "# PM Vault AI-V1" > "${tmp_plain}"
  fi

  local editor_bin="${EDITOR:-nano}"
  if command -v "${editor_bin}" >/dev/null 2>&1; then
    "${editor_bin}" "${tmp_plain}"
  else
    echo "Editor ${editor_bin} tidak ditemukan; membuat vault dari template default."
  fi

  echo "Masukkan Master Password baru untuk mengenkripsi ${VAULT_FILE}:"
  openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -in "${tmp_plain}" -out "${VAULT_FILE}"
  chmod 600 "${VAULT_FILE}"
  echo "Vault terenkripsi berhasil dibuat di ${VAULT_FILE} (chmod 600)."
}

cmd_read() {
  require_openssl
  if [[ ! -f "${VAULT_FILE}" ]]; then
    echo "Vault belum ada di ${VAULT_FILE}." >&2
    exit 1
  fi
  if [[ -n "${PM_VAULT_PASSPHRASE:-}" ]]; then
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "${VAULT_FILE}" -pass env:PM_VAULT_PASSPHRASE
  else
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "${VAULT_FILE}"
  fi
}

cmd_edit() {
  require_openssl
  if [[ ! -f "${VAULT_FILE}" ]]; then
    echo "Vault belum ada di ${VAULT_FILE}. Jalankan 'init' terlebih dahulu." >&2
    exit 1
  fi

  local tmp_plain
  tmp_plain="$(mktemp "${TMP_DIR}/pm-vault.XXXXXX")"
  chmod 600 "${tmp_plain}"
  trap 'secure_delete "'"${tmp_plain}"'"' EXIT

  echo "Masukkan Master Password untuk membuka vault:"
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in "${VAULT_FILE}" -out "${tmp_plain}"

  local editor_bin="${EDITOR:-nano}"
  "${editor_bin}" "${tmp_plain}"

  echo "Masukkan Master Password untuk menyimpan ulang vault terenkripsi:"
  openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -in "${tmp_plain}" -out "${VAULT_FILE}.tmp"
  mv "${VAULT_FILE}.tmp" "${VAULT_FILE}"
  chmod 600 "${VAULT_FILE}"
  echo "Vault berhasil diperbarui dan dienkripsi ulang."
}

cmd_verify() {
  if [[ ! -f "${VAULT_FILE}" ]]; then
    echo "STATUS: MISSING (${VAULT_FILE})"
    exit 1
  fi
  ls -la "${VAULT_FILE}"
  echo "STATUS: ENCRYPTED VAULT PRESENT (hanya untuk Admin & pm-lead)"
}

case "${1:-}" in
  init) cmd_init ;;
  read) cmd_read ;;
  edit) cmd_edit ;;
  verify) cmd_verify ;;
  *)
    echo "Penggunaan: $0 {init|read|edit|verify}"
    exit 1
    ;;
esac
