# ScannerPC

Offline-friendly malware scanning workflow for removable media. These Bash scripts provide a simple whiptail-driven menu to mount client media read-only, hash contents, run multiple scanners, and record results with optional label printing.

## Prerequisites
- Linux environment with `bash`, `whiptail`, and common coreutils.
- Malware engines and tools:
  - **ClamAV** (`clamscan`, `freshclam`) plus optional `clamav-freshclam` service.
  - **Linux Malware Detect** (`maldet`) if available.
  - Optional **YARA** rules under `/opt/yara-rules` with an `index.yar` file.
- Optional label-printing dependencies: `lp`, `zint`, and ImageMagick `convert`.
- `blockdev` and `lsblk` for device handling; `sha256sum` for hashing.

## Scripts
- `scanner-menu.sh` — whiptail menu wrapper that calls the other scripts with sudo where required.
- `prep_mount.sh` — prompts for client ID/name, enforces an air-gap check (no active IPs), lists removable unmounted partitions, sets the device read-only, and mounts it at `/mnt/scans/<client>_<timestamp>`.
- `scan_now.sh` — logs to `/var/log/malware-scans/scan_<client>_<timestamp>.log`, hashes all files for chain-of-custody, runs ClamAV and optional maldet/YARA scans, summarizes results, and can print a barcode label containing the log path.
- `eject_cleanup.sh` — unmounts the active mount, removes temporary markers, and reminds staff to restore write access if desired.
- `full_scan_sequence.sh` — orchestrates the prepare → scan → eject steps in one run without stopping for the usual menu pauses.
- `update-now.sh` — performs OS and signature updates (apt upgrade, freshclam, optional maldet/YARA pulls) when connected to an update network.
- `view_last_summary.sh` — shows the most recent scan log tail from `/var/log/malware-scans`.

## Typical workflow
1. Run `scanner-menu.sh` to open the interactive menu.
2. Choose **"Update Now"** when on the update VLAN to refresh OS and AV signatures.
3. Choose **"Prepare, Scan, and Eject"** to walk through mounting, scanning, and cleanup in one guided sequence.
4. Choose **"View Last Scan Summary"** to review the latest results.

## Installation
Use `install.sh` to deploy the scripts to a directory of your choice. Existing copies in the target directory are archived automatically before the new versions are installed, and line endings and permissions are normalized so the scripts can run at startup.

```
sudo ./install.sh -t /usr/local/bin
```

Options:
- `-t <target_dir>` (required): Destination directory for the installed scripts.
- `-a <archive_dir>` (optional): Where to store archived copies of any existing scripts (defaults to `<target_dir>/archive`).
- `-h`: Show help.

Note: The installer expects `dos2unix` to be available. Install it from your package manager if it is not already present (for example, `sudo apt-get install dos2unix`).

## Installation
Use `install.sh` to deploy the scripts to a directory of your choice. Existing copies in the target directory are archived automatically before the new versions are installed, line endings and permissions are normalized so the scripts can run at startup, and a sudoers entry is added so the scripts can be run without a password. The installer can run from any directory; if it does not find the source scripts alongside it, it will automatically clone `https://github.com/mglick-saudercpa/ScannerPC.git` and install from the freshly downloaded copy.

Download the installer directly and make it executable:

```
curl -LO https://raw.githubusercontent.com/mglick-saudercpa/ScannerPC/main/install.sh
chmod +x install.sh
sudo ./install.sh -t /usr/local/bin
```

Options:
- `-t <target_dir>` (required): Destination directory for the installed scripts.
- `-a <archive_dir>` (optional): Where to store archived copies of any existing scripts (defaults to `<target_dir>/archive`).
- `-h`: Show help.

Notes:
- The installer expects `dos2unix` to be available. Install it from your package manager if it is not already present (for example, `sudo apt-get install dos2unix`).
- Sudoers configuration uses `visudo` and writes `/etc/sudoers.d/scannerpc`; you will be prompted for sudo access if needed. The installed scripts are granted passwordless sudo as root.

## Notes
- Air-gap safety: `prep_mount.sh` refuses to mount if any network interfaces have IP addresses, prompting the operator to disconnect.
- Paths for client info and mount state are stored in `/tmp/scan_client_id`, `/tmp/scan_client_name`, and `/tmp/scan_mountpoint` for cross-script coordination.
- Scan logs and SHA256 inventories are stored under `/var/log/malware-scans/`.
- Mount points are created under `/mnt/scans/` and cleaned up by `eject_cleanup.sh`.
