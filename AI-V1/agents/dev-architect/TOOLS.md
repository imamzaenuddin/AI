# TOOLS.md — Daftar Alat & Batas Akses `dev-architect`

## 1. Path & Command yang Diizinkan
- **Workspace Proyek (`rw`):** `/workspace/<nama-app>` (di host: `/home/project/<nama-app>`)
  - Git inspection: `git status`, `git log`, `git branch`, `git diff`
  - Code search & analysis: `rg`, `grep`, `find`, `cat`/`head`/`tail`
  - Menulis dokumen standar (`AGENTS.md`, `ARCHITECTURE.md`) di proyek bila disetujui.
- **Task & Reports:** `/opt/data/shared/tasks/`, `/opt/data/shared/reports/`.

---

## 2. Larangan Alat
- Dilarang membaca isi `.env` produksi di `/workspace/<app>/.env` atau `/opt/data/.env`.
- Dilarang menjalankan perintah database destruktif (`migrate:fresh`, `db:wipe`, `DROP DATABASE`).
- Dilarang melakukan push langsung ke branch `main` produksi tanpa melewati gate `dev-qa`, `ops-secops`, dan approval `pm-lead`.

