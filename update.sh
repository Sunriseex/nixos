#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix-update

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Updating awakened-poe-trade ==="
nix-update --file "$SCRIPT_DIR/pkgs/awakened-poe-trade" --version=bump

echo ""
echo "=== Updating pob-poe2 ==="
nix-update --file "$SCRIPT_DIR/pkgs/pob-poe2" --version=bump

echo ""
echo "Done! Run 'nixos-rebuild test --flake .#desktop-pc' to apply."
