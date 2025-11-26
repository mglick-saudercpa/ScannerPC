#!/usr/bin/env bash
set -euo pipefail

# Installer for ScannerPC bash scripts
# - Archives existing installed scripts before replacing them
# - Copies the new scripts to a user-specified target directory
# - Normalizes line endings with dos2unix
# - Applies secure execute permissions for startup use
# - Configures passwordless sudo access for the installed scripts via visudo

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_URL="https://github.com/mglick-saudercpa/ScannerPC.git"
SOURCE_DIR="$SCRIPT_DIR"
CLONE_DIR=""
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

if ! command -v sudo >/dev/null 2>&1; then
  echo "Error: sudo is required to configure sudoers entries." >&2
  exit 1
fi

if ! command -v visudo >/dev/null 2>&1; then
  echo "Error: visudo is required to safely configure sudoers entries." >&2
  exit 1
fi

ensure_source_scripts() {
  local missing=false

  for script in "${SCRIPTS[@]}"; do
    if [[ ! -f "$SOURCE_DIR/$script" ]]; then
      missing=true
      break
    fi
  done

  if [[ "$missing" == true ]]; then
    if ! command -v git >/dev/null 2>&1; then
      echo "Error: git is required to download scripts from $REPO_URL" >&2
      exit 1
    fi

    CLONE_DIR=$(mktemp -d)
    trap '[[ -n "$CLONE_DIR" ]] && rm -rf "$CLONE_DIR"' EXIT

    echo "Source scripts not found alongside installer; cloning $REPO_URL..."
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    SOURCE_DIR="$CLONE_DIR"
  fi
}

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
    local source_file="$SOURCE_DIR/$script"
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

configure_sudoers() {
  local tmp_file sudoers_entry_file script_paths joined_paths
  tmp_file=$(mktemp)
  sudoers_entry_file="/etc/sudoers.d/scannerpc"

  script_paths=()
  for script in "${SCRIPTS[@]}"; do
    script_paths+=("$TARGET_DIR/$script")
  done

  joined_paths=""
  for path in "${script_paths[@]}"; do
    if [[ -z "$joined_paths" ]]; then
      joined_paths="$path"
    else
      joined_paths="$joined_paths, $path"
    fi
  done

  cat >"$tmp_file" <<EOF
# Passwordless sudo for ScannerPC scripts installed to $TARGET_DIR
ALL ALL=(root) NOPASSWD: $joined_paths
EOF

  if ! sudo visudo -cf "$tmp_file"; then
    echo "Error: generated sudoers entry failed validation; not installing." >&2
    rm -f "$tmp_file"
    exit 1
  fi

  sudo install -m 440 "$tmp_file" "$sudoers_entry_file"
  rm -f "$tmp_file"

  echo "Configured passwordless sudo for ScannerPC scripts in $sudoers_entry_file"
}

archive_existing
ensure_source_scripts
copy_scripts
configure_sudoers

echo "Installation complete. Scripts installed to $TARGET_DIR"
