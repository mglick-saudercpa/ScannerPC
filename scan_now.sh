#!/usr/bin/env bash
set -euo pipefail

LOGDIR="/var/log/malware-scans"
mkdir -p "$LOGDIR"
STAMP=$(date -u +"%Y%m%dT%H%M%SZ")

# pick up client info set by prep_mount.sh
CLIENT_ID="UnknownID"
CLIENT_NAME="UnknownClient"
if [ -f /tmp/scan_client_id ]; then
  CLIENT_ID=$(cat /tmp/scan_client_id)
fi
if [ -f /tmp/scan_client_name ]; then
  CLIENT_NAME=$(cat /tmp/scan_client_name)
fi

BASENAME="scan_${CLIENT_ID}_${CLIENT_NAME}_${STAMP}"
LOG="$LOGDIR/${BASENAME}.log"
SUM="$LOGDIR/${BASENAME}.sha256"

if [ ! -f /tmp/scan_mountpoint ]; then
  echo "No mountpoint found. Run 'Prepare & Mount' first."
  echo
  echo "Press Enter to return to the menu..."
  read -r
  exit 1
fi
MNT=$(cat /tmp/scan_mountpoint)

echo "=== SCAN START $STAMP ===" | tee -a "$LOG"
echo "Client ID:   $CLIENT_ID" | tee -a "$LOG"
echo "Client Name: $CLIENT_NAME" | tee -a "$LOG"
echo "Mountpoint:  $MNT" | tee -a "$LOG"

# Hash listing for chain-of-custody
echo "Hashing files (this may take time)..." | tee -a "$LOG"
find "$MNT" -type f -readable -print0 | xargs -0 sha256sum > "$SUM" || true
echo "SHA256 list: $SUM" | tee -a "$LOG"

# ClamAV scan (ClamAV 1.x: no max-size flags)
echo "--- ClamAV ---" | tee -a "$LOG"
clamscan -r --detect-pua=yes --phishing-sigs=yes --phishing-scan-urls=yes \
  "$MNT" | tee -a "$LOG"

# Linux Malware Detect (uses ClamAV engine if present)
if command -v maldet >/dev/null 2>&1; then
  echo "--- maldet ---" | tee -a "$LOG"
  maldet -a "$MNT" | tee -a "$LOG" || true
fi

# Optional YARA
if [ -d /opt/yara-rules ]; then
  echo "--- YARA (IOC sweep) ---" | tee -a "$LOG"
  find "$MNT" -type f \( -iname "*.exe" -o -iname "*.dll" -o -iname "*.docm" -o -iname "*.js" \) -print0 \
    | xargs -0 -I{} yara -r /opt/yara-rules/index.yar "{}" 2>/dev/null | tee -a "$LOG" || true
fi

echo "=== SCAN END $STAMP ===" | tee -a "$LOG"

INFECTED=$(grep -E "Infected files:|FOUND" -c "$LOG" || true)
echo "Scan complete. Potential hits: $INFECTED" | tee -a "$LOG"
echo "Summary:"
echo "  Client ID:   $CLIENT_ID"
echo "  Client Name: $CLIENT_NAME"
echo "  Log:         $LOG"
echo "  Hashes:      $SUM"

echo
echo "Press Enter to return to the menu..."
read -r
