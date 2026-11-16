# MEMORY.md — Memori Awal `dev-qa`

## Aturan QA & Rilis AI-V1
- Setiap rilis ProjectWeb ke produksi wajib melewati 4 pemeriksaan: `dev-architect` (Code Review), `dev-qa` (QA Pass), `ops-secops` (Sec Pass), dan `ops-backup-dba` (Backup Ready).
- Endpoint publik di Nginx harus merespons dengan sertifikat SSL valid yang sesuai subdomain (waspadai error `SEC_E_WRONG_PRINCIPAL` atau `502 Bad Gateway`).
- Dilarang menjalankan automated test yang bersifat destructive pada database produksi.

## Catatan Pengujian Proyek
- *(Akan diisi seiring berjalannya pengujian aplikasi di `/workspace`).*

