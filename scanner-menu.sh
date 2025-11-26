#!/usr/bin/env bash
set -euo pipefail
while true; do
  CHOICE=$(whiptail --title "Malware Scanner" --menu "Choose an action" 20 72 10 \
    1 "Update Now (requires Update VLAN)" \
    2 "Prepare, Scan, and Eject (full sequence)" \
    3 "View Last Scan Summary" \
    4 "Exit" 3>&1 1>&2 2>&3) || exit 0

  case "$CHOICE" in
    1) sudo /opt/scanner-bin/update_now.sh ;;
    2) sudo /opt/scanner-bin/full_scan_sequence.sh ;;
    3) /opt/scanner-bin/view_last_summary.sh ;;
    4) exit 0 ;;
  esac
done
set -euo pipefail

LOGDIR="/var/log/malware-scans"

get_last_update() {
  local latest_file

  if compgen -G "$LOGDIR/update_*.log" >/dev/null; then
    latest_file=$(ls -1t "$LOGDIR"/update_*.log 2>/dev/null | head -n1)
    if [ -n "$latest_file" ]; then
      date -r "$latest_file" '+%Y-%m-%d %H:%M UTC'
      return
    fi
  fi

  echo "Never"
}
while true; do
  LAST_UPDATE=$(get_last_update)
  CHOICE=$(whiptail --title "Malware Scanner" --menu "Choose an action" 20 72 10 \
    1 "Update Now (Last Updated: $LAST_UPDATE)" \
    2 "Prepare & Mount Read-Only" \
    3 "Scan Mounted Media" \
    4 "Eject & Clean Up" \
    5 "View Last Scan Summary" \
    6 "Exit" 3>&1 1>&2 2>&3) || exit 0

  case "$CHOICE" in
    1) sudo /opt/scanner-bin/update_now.sh ;;
    2) sudo /opt/scanner-bin/prep_mount.sh ;;
    3) sudo /opt/scanner-bin/scan_now.sh ;;
    4) sudo /opt/scanner-bin/eject_cleanup.sh ;;
    5) /opt/scanner-bin/view_last_summary.sh ;;
    6) exit 0 ;;
  esac
done
