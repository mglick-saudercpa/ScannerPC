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

print_label() {
  local result="$1"

  if ! command -v lp >/dev/null 2>&1; then
    echo "Label printer not available (lp command missing)." | tee -a "$LOG"
    return
  fi

  if ! command -v zint >/dev/null 2>&1; then
    echo "Cannot create barcode (zint missing); skipping label print." | tee -a "$LOG"
    return
  fi

  if ! command -v convert >/dev/null 2>&1; then
    echo "Cannot compose label image (ImageMagick convert missing); skipping label print." | tee -a "$LOG"
    return
  fi

  local label_tmp
  label_tmp=$(mktemp -d)
  trap 'rm -rf "${label_tmp:-}"' EXIT

  local eastern_stamp
  eastern_stamp=$(TZ=America/New_York date +"%Y-%m-%d %H:%M %Z")

  local barcode_file label_image
  barcode_file="$label_tmp/logpath_code128.png"
  label_image="$label_tmp/label.png"

  if ! zint --barcode=20 --scale=2 --border=2 --notext -o "$barcode_file" --data "$LOG"; then
    echo "Barcode generation failed; skipping label print." | tee -a "$LOG"
    return
  fi

  local label_text
  label_text="$CLIENT_NAME\nScan Result: $result\n$eastern_stamp\nLog path (Code 128)"

  if ! convert "$barcode_file" -resize 380x80 -gravity north -background white -splice 0x120 \
    -pointsize 16 -annotate +0+10 "$label_text" "$label_image"; then
    echo "Failed to compose label image; skipping label print." | tee -a "$LOG"
    return
  fi

  echo "Sending label to printer..." | tee -a "$LOG"
  lp "$label_image" || echo "Label print failed; check printer connection." | tee -a "$LOG"
}

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
if [ "$INFECTED" -gt 0 ]; then
  SCAN_RESULT="Issues Found ($INFECTED)"
else
  SCAN_RESULT="Clean"
fi
echo "Scan complete. Potential hits: $INFECTED" | tee -a "$LOG"
echo "Summary:"
echo "  Client ID:   $CLIENT_ID"
echo "  Client Name: $CLIENT_NAME"
echo "  Log:         $LOG"
echo "  Hashes:      $SUM"

print_label "$SCAN_RESULT"

echo
echo "Press Enter to return to the menu..."
read -r
