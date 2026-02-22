#!/usr/bin/env bash
set -euo pipefail

assume_yes=0
dry_run=0
with_docker=0
verbose=0
sudo_checked=0
log_file="${TMPDIR:-/tmp}/disk-cleanup.$$.log"

trap 'rm -f "$log_file"' EXIT

usage() {
  cat <<'EOF'
Usage: disk-cleanup.sh [--yes] [--dry-run] [--docker] [--verbose]

Options:
  --yes      Run without confirmation prompts
  --dry-run  Print commands without executing them
  --docker   Also run docker system prune (removes unused data)
  --verbose  Show full command output
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      assume_yes=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    --docker)
      with_docker=1
      ;;
    --verbose)
      verbose=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

confirm() {
  local prompt="$1"
  if [[ "$assume_yes" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

run_cmd() {
  local description="$1"
  shift

  echo
  echo "==> $description"
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'DRY-RUN:'
    printf ' %q' "$@"
    echo
    return 0
  fi

  if [[ "$verbose" -eq 1 ]]; then
    "$@"
    return 0
  fi

  if "$@" >"$log_file" 2>&1; then
    echo "done"
  else
    echo "failed"
    echo "Last command output:"
    tail -n 20 "$log_file" || true
    echo "Tip: rerun with --verbose for full output."
    return 1
  fi
}

ensure_sudo() {
  if [[ "$dry_run" -eq 1 ]]; then
    return 0
  fi
  if [[ "$sudo_checked" -eq 0 ]]; then
    echo
    echo "==> sudo authentication"
    sudo -v
    sudo_checked=1
  fi
}

echo "Disk usage before cleanup:"
df -h /

if confirm "Run system and user Nix garbage collection?"; then
  ensure_sudo
  run_cmd "System Nix GC" sudo nix-collect-garbage -d
  run_cmd "User Nix GC" nix-collect-garbage -d
fi

if confirm "Run Nix store optimization (hard-link deduplication)?"; then
  ensure_sudo
  run_cmd "Nix store optimise" sudo nix store optimise
fi

if confirm "Vacuum systemd journal older than 14 days?"; then
  ensure_sudo
  run_cmd "Journal vacuum" sudo journalctl --vacuum-time=14d
fi

if [[ "$with_docker" -eq 1 ]]; then
  if command -v docker >/dev/null 2>&1; then
    if confirm "Run docker system prune (including volumes)?"; then
      ensure_sudo
      run_cmd "Docker prune" sudo docker system prune -af --volumes
    fi
  else
    echo
    echo "Docker not found in PATH, skipping docker cleanup."
  fi
fi

echo
echo "Disk usage after cleanup:"
df -h /
