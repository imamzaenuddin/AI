#!/usr/bin/env bash
# ==============================================================================
# AI-V1 Real-Time CLI Status Monitor
# Memantau seluruh layanan VPS, container Hermes, profil agent, model AI,
# worklog pekerjaan, endpoint HTTPS, dan log setup secara real-time di CLI VPS.
#
# Penggunaan:
#   bash /opt/AI-V1/AI-V1/scripts/monitor-cli.sh          # Tampilkan sekali
#   bash /opt/AI-V1/AI-V1/scripts/monitor-cli.sh --watch  # Live refresh tiap 5 detik
# ==============================================================================

set -u

WATCH_MODE=false
if [[ "${1:-}" == "--watch" ]]; then
  WATCH_MODE=true
fi

print_status() {
  local green="\033[0;32m"
  local yellow="\033[0;33m"
  local red="\033[0;31m"
  local cyan="\033[0;36m"
  local reset="\033[0m"

  echo -e "${cyan}======================================================================${reset}"
  echo -e "${cyan}  AI-V1 VPS LIVE CLI MONITOR  |  $(hostname)  |  $(date '+%Y-%m-%d %H:%M:%S')${reset}"
  echo -e "${cyan}======================================================================${reset}"

  echo -e "\n[1] RESOURCE VPS"
  df -h / | awk 'NR==2{printf "  Disk (/) : %s / %s (%s terpakai, sisa %s)\n", $3, $2, $5, $4}'
  free -h | awk '/^Mem:/{printf "  RAM      : %s / %s (tersedia %s)\n", $3, $2, $7}'

  echo -e "\n[2] SYSTEMD SERVICES"
  for s in nginx mariadb php8.3-fpm 9router code-server vps-monitor docker; do
    st="$(systemctl is-active "$s" 2>/dev/null || echo "missing")"
    if [[ "$st" == "active" ]]; then
      printf "  %-14s : ${green}%s${reset}\n" "$s" "$st"
    else
      printf "  %-14s : ${red}%s${reset}\n" "$s" "$st"
    fi
  done

  echo -e "\n[3] DOCKER HERMES CONTAINERS"
  if command -v docker >/dev/null 2>&1; then
    docker ps -a --format "  {{.Names}}\t{{.Status}}" 2>/dev/null || echo "  (tidak bisa membaca docker)"
  else
    echo "  (docker belum terpasang)"
  fi

  echo -e "\n[4] STATUS PROFIL, VAULT, & PLUGIN OFFICE-3D"
  local p_count=0
  [[ -d /opt/hermes/data/profiles ]] && p_count="$(find /opt/hermes/data/profiles -mindepth 1 -maxdepth 1 -type d | wc -l)"
  echo "  Profil Agent     : ${p_count} / 8 terpasang"
  [[ -f /opt/hermes/data/credentials/pm-vault.enc ]] && echo -e "  PM-Only Vault    : ${green}TERKUNCI (pm-vault.enc)${reset}" || echo -e "  PM-Only Vault    : ${yellow}BELUM ADA${reset}"
  if [[ -d /opt/hermes/data/plugins/office-3d || -d /opt/hermes/data/desktop-plugins/office-3d ]]; then
    echo -e "  Plugin Office-3D : ${green}TERPASANG${reset}"
  else
    echo -e "  Plugin Office-3D : ${yellow}BELUM ADA${reset}"
  fi

  echo -e "\n[5] STATUS MODEL AI (CRON) & WORKLOG"
  if [[ -f /opt/hermes/data/shared/reports/model-health.json ]]; then
    python3 - <<'PY' 2>/dev/null || echo "  (gagal parse model-health.json)"
import json
d = json.load(open("/opt/hermes/data/shared/reports/model-health.json"))
gw = "OK" if d.get("ninerouter_reachable") else "ERR"
print(f"  Model Check ({d.get('checked_at','-')}): 9Router={gw} | Fallback={d.get('working_fallback') or '-'}")
for a in d.get("agents", []):
    print(f"    - {a['agent']:18s} -> {str(a.get('model')):32s} [{a.get('status')}]")
PY
  else
    echo "  (belum ada laporan model-health.json)"
  fi

  if [[ -f /opt/hermes/data/shared/tasks/worklog.json ]]; then
    python3 - <<'PY' 2>/dev/null || true
import json
w = json.load(open("/opt/hermes/data/shared/tasks/worklog.json"))
print(f"  Worklog Update   : {w.get('updated_at','-')} | Sedang Dikerjakan: {len(w.get('active_work',[]))} | Selesai: {len(w.get('completed_work',[]))}")
PY
  fi

  echo -e "\n[6] ENDPOINT HTTP/HTTPS"
  for url in "https://hermes.imam.my.id/" "https://9router.imam.my.id/" "https://code.imam.my.id/" "https://e-masjid.imam.my.id/" "https://sim-pt.imam.my.id/" "https://webkampus.imam.my.id/" "http://127.0.0.1:9120/health"; do
    code="$(curl -sk -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null || echo "ERR")"
    if [[ "$code" == "200" || "$code" == "302" || "$code" == "401" ]]; then
      printf "  %-34s : ${green}HTTP %s${reset}\n" "$url" "$code"
    else
      printf "  %-34s : ${red}HTTP %s${reset}\n" "$url" "$code"
    fi
  done

  if [[ -f /var/log/aiv1-autonomous.log ]]; then
    echo -e "\n[7] LOG AUTONOMOUS TERAKHIR (/var/log/aiv1-autonomous.log)"
    tail -n 6 /var/log/aiv1-autonomous.log | sed 's/^/  /'
  fi
}

if [[ "${WATCH_MODE}" == "true" ]]; then
  while true; do
    clear
    print_status
    echo -e "\n(Tekan Ctrl+C untuk keluar; refresh tiap 5 detik)"
    sleep 5
  done
else
  print_status
fi

