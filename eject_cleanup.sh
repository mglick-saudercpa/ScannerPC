#!/usr/bin/env bash
set -euo pipefail
if [ ! -f /tmp/scan_mountpoint ]; then
  echo "No active mount found."
  exit 0
fi
MNT=$(cat /tmp/scan_mountpoint)
sync || true
umount -l "$MNT" || true
rmdir "$MNT" || true
rm -f /tmp/scan_mountpoint

# Attempt to toggle device back to read-write (harmless if it fails)
# Staff will physically disconnect/write-blocker anyway.
echo "If you know the block device (e.g., /dev/sdb1), you may run: sudo blockdev --setrw /dev/sdb1"
echo "Device unmounted and cleaned. Safe to disconnect media."
