#!/usr/bin/env bash
set -euo pipefail

MNTBASE="/mnt/scans"
mkdir -p "$MNTBASE"

# --- Air-gap safety check ---
ACTIVE_IPS=$(ip -o addr show up scope global | awk '{print $2": "$4}')
if [ -n "$ACTIVE_IPS" ]; then
  echo "Refusing to mount while network interfaces have IP addresses assigned."
  echo "Detected addresses:"
  echo "$ACTIVE_IPS"
  echo
  echo "Disconnect from all networks to maintain the air-gap, then try again."
  echo "Press Enter to return to the menu..."
  read -r
  exit 1
fi

# --- Prompt for client info ---
echo "Enter client ID (e.g. account number or internal code, no spaces recommended):"
read -rp "Client ID: " CLIENT_ID
[ -z "${CLIENT_ID:-}" ] && CLIENT_ID="UnknownID"

echo "Enter client short name / abbreviation (e.g. MillerFarms, KingMetal):"
read -rp "Client name: " CLIENT_NAME
[ -z "${CLIENT_NAME:-}" ] && CLIENT_NAME="UnknownClient"

# Sanitize for use in paths
CLIENT_ID_SAFE="$(echo "$CLIENT_ID" | tr -cd '[:alnum:]_-')"
[ -z "$CLIENT_ID_SAFE" ] && CLIENT_ID_SAFE="UnknownID"
CLIENT_NAME_SAFE="$(echo "$CLIENT_NAME" | tr -cd '[:alnum:]_-')"
[ -z "$CLIENT_NAME_SAFE" ] && CLIENT_NAME_SAFE="UnknownClient"

# Store for scan_now.sh to pick up
echo "$CLIENT_ID_SAFE" > /tmp/scan_client_id
echo "$CLIENT_NAME_SAFE" > /tmp/scan_client_name

# --- Build device menu (removable, unmounted partitions) ---
mapfile -t CANDIDATES < <(
  lsblk -o NAME,SIZE,RO,TYPE,RM,MOUNTPOINT -nr \
    | awk '$4=="part" && $5=="1" && $6=="" {print $1" "$2" "$3}'
)

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  echo "No removable, unmounted partitions found."
  echo "Insert a USB or external drive and try again."
  echo
  echo "Press Enter to return to the menu..."
  read -r
  exit 1
fi

MENU_OPTS=()
for line in "${CANDIDATES[@]}"; do
  name=$(echo "$line" | awk '{print $1}')
  size=$(echo "$line" | awk '{print $2}')
  ro=$(echo  "$line" | awk '{print $3}')
  MENU_OPTS+=("$name" "$name (size=$size, ro=$ro)")
done

CHOICE=$(whiptail --title "Select device to mount" \
  --menu "Client: ${CLIENT_ID_SAFE} / ${CLIENT_NAME_SAFE}\nChoose a removable partition to mount read-only:" \
  20 78 10 \
  "${MENU_OPTS[@]}" \
  3>&1 1>&2 2>&3) || exit 0

DEV="/dev/$CHOICE"
echo "Selected device: $DEV"

# Set kernel block device read-only (best-effort)
blockdev --setro "$DEV" || true

STAMP=$(date -u +"%Y%m%dT%H%M%SZ")
MNT="$MNTBASE/${CLIENT_ID_SAFE}_${CLIENT_NAME_SAFE}_${STAMP}"
mkdir -p "$MNT"

echo "Attempting to mount $DEV at $MNT (read-only)..."
if ! mount -o ro,nosuid,nodev,noexec "$DEV" "$MNT"; then
  echo "Automatic mount failed; specify filesystem type (ntfs/exfat/vfat/ext4):"
  read -rp "Filesystem type: " FST
  mount -t "$FST" -o ro,nosuid,nodev,noexec "$DEV" "$MNT"
fi

echo "Mounted $DEV at $MNT (read-only)."
echo "$MNT" > /tmp/scan_mountpoint

echo
echo "Press Enter to return to the menu..."
read -r
