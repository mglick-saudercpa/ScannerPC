#!/usr/bin/env bash
set -euo pipefail
LOGDIR="/var/log/malware-scans"
mkdir -p "$LOGDIR"
STAMP=$(date -u +"%Y%m%dT%H%M%SZ")
LOG="$LOGDIR/update_$STAMP.log"

echo "=== UPDATE START $STAMP ===" | tee -a "$LOG"
# Optional: sanity check network reachability
if ! ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
  echo "No network: ensure Update VLAN is connected." | tee -a "$LOG"
  exit 1
fi

# OS & engine updates
apt-get update | tee -a "$LOG"
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade | tee -a "$LOG"
# AV signatures
systemctl stop clamav-freshclam || true
freshclam | tee -a "$LOG"
systemctl start clamav-freshclam || true
# Maldet and YARA rules (if using community rules)
if command -v maldet >/dev/null 2>&1; then
  maldet -u | tee -a "$LOG" || true
fi
if [ -d /opt/yara-rules/.git ]; then
  git -C /opt/yara-rules pull | tee -a "$LOG" || true
fi

echo "=== UPDATE END $STAMP ===" | tee -a "$LOG"
echo "Update complete. Log: $LOG"
