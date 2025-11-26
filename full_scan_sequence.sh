#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/scanner-bin"

run_step() {
  local step_label=$1
  shift
  echo "=== $step_label ==="
  if ! "$@"; then
    echo "$step_label failed; aborting sequence." >&2
    return 1
  fi
  return 0
}

SKIP_PAUSE=1 run_step "Prepare & Mount" sudo "$BASE/prep_mount.sh"

if SKIP_PAUSE=1 run_step "Scan" sudo "$BASE/scan_now.sh"; then
  run_step "Eject & Clean Up" sudo "$BASE/eject_cleanup.sh"
else
  echo "Attempting cleanup after scan failure..." >&2
  sudo "$BASE/eject_cleanup.sh" || true
  exit 1
fi
