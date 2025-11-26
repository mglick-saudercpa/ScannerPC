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
