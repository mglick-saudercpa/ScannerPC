#!/usr/bin/env bash
set -euo pipefail

# Installer for ScannerPC bash scripts
# - Archives existing installed scripts before replacing them
# - Copies the new scripts to a user-specified target directory
# - Normalizes line endings with dos2unix
# - Applies secure execute permissions for startup use

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPTS=(
  "scanner-menu.sh"
  "prep_mount.sh"
  "scan_now.sh"
  "eject_cleanup.sh"
  "update-now.sh"
  "view_last_summary.sh"
)

usage() {
  cat <<USAGE
Usage: $0 -t <target_dir> [-a <archive_dir>]

  -t  Destination directory to install the scripts into (required).
  -a  Directory to store archived copies of any existing installed scripts.
      Defaults to <target_dir>/archive.
  -h  Show this help message.
USAGE
}

TARGET_DIR=""
ARCHIVE_DIR=""

while getopts ":t:a:h" opt; do
  case "$opt" in
    t) TARGET_DIR=$OPTARG ;;
    a) ARCHIVE_DIR=$OPTARG ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage; exit 1 ;;
    *) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  echo "Error: target directory is required." >&2
  usage
  exit 1
fi

if ! command -v dos2unix >/dev/null 2>&1; then
  echo "Error: dos2unix is not installed. Install it and rerun this installer." >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
ARCHIVE_DIR=${ARCHIVE_DIR:-"$TARGET_DIR/archive"}

archive_existing() {
  local timestamp archive_path
  timestamp=$(date +%Y%m%d_%H%M%S)
  archive_path="$ARCHIVE_DIR/$timestamp"
  local archived_any=false

  mkdir -p "$archive_path"

  for script in "${SCRIPTS[@]}"; do
    local target_file="$TARGET_DIR/$script"
    if [[ -f "$target_file" ]]; then
      cp -a "$target_file" "$archive_path/"
      archived_any=true
    fi
  done

  if [[ "$archived_any" == true ]]; then
    echo "Archived existing scripts to $archive_path"
  else
    rmdir "$archive_path" 2>/dev/null || true
    echo "No existing scripts to archive."
  fi
}

copy_scripts() {
  for script in "${SCRIPTS[@]}"; do
    local source_file="$SCRIPT_DIR/$script"
    local target_file="$TARGET_DIR/$script"
    if [[ ! -f "$source_file" ]]; then
      echo "Warning: source script $source_file not found; skipping." >&2
      continue
    fi

    cp "$source_file" "$target_file"
    dos2unix "$target_file" >/dev/null

    if [[ "$script" == "scanner-menu.sh" ]]; then
      chmod 755 "$target_file"
    else
      chmod 750 "$target_file"
    fi
  done
}

archive_existing
copy_scripts

echo "Installation complete. Scripts installed to $TARGET_DIR"
