#!/usr/bin/env bash
set -euo pipefail
LASTLOG=$(ls -1t /var/log/malware-scans/scan_*.log 2>/dev/null | head -n1 || true)
if [ -z "$LASTLOG" ]; then
  echo "No scan logs found."
  exit 0
fi
echo "Last scan log: $LASTLOG"
tail -n 50 "$LASTLOG"
