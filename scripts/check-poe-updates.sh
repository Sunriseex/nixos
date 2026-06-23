#!/usr/bin/env bash
# Checks for new versions of PoE-related apps on GitHub
set -euo pipefail

REPO_DIR="/home/snrx/nixos"

notify() {
  notify-send "PoE Apps Update" "$1" --icon=software-update-available --urgency=normal
}

extract_version() {
  sed -n 's/^  version = "\(.*\)";/\1/p' "$1"
}

fetch_latest_tag() {
  local repo="$1"
  curl -sL "https://api.github.com/repos/${repo}/releases/latest" | sed -n 's/.*"tag_name": *"v\(.*\)",/\1/p'
}

updates=()

# awakened-poe-trade
apt_pkg="$REPO_DIR/pkgs/awakened-poe-trade/default.nix"
if [ -f "$apt_pkg" ]; then
  current_apt="$(extract_version "$apt_pkg")"
  latest_apt="$(fetch_latest_tag "SnosMe/awakened-poe-trade" || true)"
  if [ -n "$latest_apt" ] && [ "$current_apt" != "$latest_apt" ]; then
    updates+=("Awakened PoE Trade: $current_apt → $latest_apt")
  fi
fi

# pob-poe1
pob1_pkg="$REPO_DIR/pkgs/pob-poe1/default.nix"
if [ -f "$pob1_pkg" ]; then
  current_pob1="$(extract_version "$pob1_pkg")"
  latest_pob1="$(fetch_latest_tag "PathOfBuildingCommunity/PathOfBuilding" || true)"
  if [ -n "$latest_pob1" ] && [ "$current_pob1" != "$latest_pob1" ]; then
    updates+=("Path of Building PoE1: $current_pob1 → $latest_pob1")
  fi
fi

# pob-poe2
pob2_pkg="$REPO_DIR/pkgs/pob-poe2/default.nix"
if [ -f "$pob2_pkg" ]; then
  current_pob2="$(extract_version "$pob2_pkg")"
  latest_pob2="$(fetch_latest_tag "PathOfBuildingCommunity/PathOfBuilding-PoE2" || true)"
  if [ -n "$latest_pob2" ] && [ "$current_pob2" != "$latest_pob2" ]; then
    updates+=("Path of Building PoE2: $current_pob2 → $latest_pob2")
  fi
fi

if [ ${#updates[@]} -gt 0 ]; then
  msg=""
  for u in "${updates[@]}"; do
    msg+="$u\n"
  done
  notify "$(echo -e "$msg")"
fi
