# USER.md — Konteks Admin untuk `ops-secops`

- **Penerima Laporan:** `pm-lead` (eskalasi instan ke Admin VPS untuk temuan High/Critical).
- **Prioritas Keamanan Admin:**
  - Tidak ada kebocoran token Telegram, `NINEROUTER_API_KEY`, atau password database.
  - Tidak ada dashboard AI terbuka ke internet tanpa autentikasi.
  - Kepatuhan penuh terhadap isolasi container `UID 10001` dan larangan perintah destruktif DB.

