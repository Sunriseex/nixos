#!/usr/bin/env bash
set -euo pipefail

# === Config ===
assume_yes=0
dry_run=0
with_docker=0
aggressive=0
verbose=0
quiet=0
keep=3
journal_days=14
declare -a extra_targets=()
log_file="${TMPDIR:-/tmp}/disk-cleanup.$$.log"
trap 'rm -f "$log_file"' EXIT

# === Colors ===
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && command -v tput &>/dev/null; then
  BOLD=$(tput bold)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  NC=$(tput sgr0)
else
  BOLD=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''
fi

# === Help ===
usage() {
  cat <<EOF
Usage: disk-cleanup.sh [options]

Options:
  --yes                  Run without confirmation prompts
  --dry-run              Print actions without executing
  --docker               Also prune Docker (images, containers, volumes)
  --aggressive           Extra cleanups: caches, flatpak, trash, btrfs balance
  --keep N               Keep N newest generations (default: delete all old)
  --journal-days N       Journal retention in days (default: 14)
  --target /path         Additional mount point to clean (can be repeated)
  --verbose              Show full command output
  --quiet                Suppress disk usage summary
  -h, --help             Show this help
EOF
}

# === Log helpers ===
log_header()  { echo -e "  ${BLUE}==>${NC} ${BOLD}$*${NC}"; }
log_ok()      { echo -e "  ${GREEN}done${NC} $*"; }
log_fail()    { echo -e "  ${RED}failed${NC} $*"; }
log_warn()    { echo -e "  ${YELLOW}warning:${NC} $*"; }
log_freed()   { echo -e "  ${GREEN}freed:${NC} ${YELLOW}$*${NC}"; }

human_size() {
  local bytes=$1
  if command -v numfmt &>/dev/null; then
    numfmt --to=iec "$bytes"
  else
    local units=("B" "K" "M" "G" "T")
    local i=0
    local val=$bytes
    while [[ $val -gt 1024 && $i -lt 4 ]]; do
      val=$(( val / 1024 ))
      i=$(( i + 1 ))
    done
    echo "${val}${units[$i]}"
  fi
}

# === Mount helpers ===
get_physical_mounts() {
  findmnt -n -o TARGET -t btrfs,ext4,xfs,zfs 2>/dev/null | sort -u
}

show_disk_usage() {
  local mounts=("$@")
  printf "  %-20s %8s %8s %5s\n" "Mount" "Used" "Avail" "Use%"
  printf "  %s\n" "------------------------------------------"
  for m in "${mounts[@]}"; do
    if [[ -d "$m" ]]; then
      df -h "$m" 2>/dev/null | tail -1 | awk -v m="$m" '{printf "  %-20s %8s %8s %5s\n", m, $3, $4, $5}'
    fi
  done
}

take_snapshot() {
  local mount="$1"
  _fs_before["$mount"]=$(df --output=avail "$mount" 2>/dev/null | tail -1) || _fs_before["$mount"]=0
}

get_freed() {
  local mount="$1"
  local after
  after=$(df --output=avail "$mount" 2>/dev/null | tail -1) || after=0
  local diff=$(( after - _fs_before["$mount"] ))
  echo "$diff"
}

declare -A _fs_before

# === Confirmation ===
confirm() {
  local prompt="$1"
  if [[ "$assume_yes" -eq 1 ]]; then return 0; fi
  read -r -p "$prompt [y/N]: " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

ensure_sudo() {
  if [[ "$dry_run" -eq 1 ]]; then return 0; fi
  if [[ "${_sudo_checked:-0}" -eq 0 ]]; then
    echo; log_header "sudo authentication"
    sudo -v
    _sudo_checked=1
  fi
}

# === Step runner ===
run_step() {
  local description="$1"
  local mount="$2"   # "" = no freed tracking
  shift 2

  local before=0
  if [[ -n "$mount" ]]; then
    before=$(df --output=avail "$mount" 2>/dev/null | tail -1) || before=0
  fi

  echo; log_header "$description"
  if [[ "$dry_run" -eq 1 ]]; then
    printf '  DRY-RUN:'
    printf ' %q' "$@"
    echo
    return 0
  fi

  if [[ "$verbose" -eq 1 ]]; then
    "$@"; rc=$?
  else
    "$@" >"$log_file" 2>&1; rc=$?
  fi

  if [[ $rc -eq 0 ]]; then
    log_ok
  else
    log_fail "(exit $rc)"
    if [[ "$verbose" -eq 0 ]]; then
      echo "  Last command output:"
      tail -n 10 "$log_file" 2>/dev/null || true
      echo "  Tip: rerun with --verbose"
    fi
    return 1
  fi

  if [[ -n "$mount" ]]; then
    local after
    after=$(df --output=avail "$mount" 2>/dev/null | tail -1) || after=0
    local diff=$(( after - before ))
    if [[ $diff -gt 0 ]]; then
      log_freed "$(human_size $(( diff * 1024 )))"
    fi
  fi
}

# Nix generation cleanup with dry-run support
clean_nix_generations() {
  local profile="$1"   # "" = default user profile
  local sudo="$2"      # "sudo" or ""
  local label="$3"

  if [[ "$dry_run" -eq 1 ]]; then
    local keep_msg=""
    local count=0
    if [[ -z "$profile" ]]; then
      count=$(nix-env --list-generations 2>/dev/null | grep -c .) || count=0
    else
      count=$($sudo sh -c "ls ${profile}-*-link 2>/dev/null" | wc -l) || count=0
    fi
    local to_delete=$(( count > 1 ? count - 1 : 0 ))
    if [[ "$keep" -gt 0 ]]; then
      to_delete=$(( count > keep ? count - keep : 0 ))
      keep_msg=" (keeping last $keep)"
    fi
    log_header "$label Nix GC (dry-run)"
    echo "  would delete: $to_delete old generations out of $count$keep_msg"
    return 0
  fi

  if [[ "$keep" -gt 0 ]]; then
    if [[ -z "$profile" ]]; then
      nix-env --delete-generations +$keep 2>/dev/null || true
    else
      $sudo nix-env --delete-generations +$keep -p "$profile" 2>/dev/null || true
    fi
  else
    if [[ -z "$profile" ]]; then
      nix-collect-garbage -d 2>/dev/null || true
    else
      $sudo nix-collect-garbage -d 2>/dev/null || true
    fi
  fi
}

# === Parse args ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) assume_yes=1 ;;
    --dry-run) dry_run=1 ;;
    --docker) with_docker=1 ;;
    --aggressive) aggressive=1 ;;
    --verbose) verbose=1 ;;
    --quiet) quiet=1 ;;
    --keep) keep="$2"; shift ;;
    --keep=*) keep="${1#*=}" ;;
    --journal-days) journal_days="$2"; shift ;;
    --journal-days=*) journal_days="${1#*=}" ;;
    --target) extra_targets+=("$2"); shift ;;
    --target=*) extra_targets+=("${1#*=}") ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage; exit 1
      ;;
  esac
  shift
done

# === Main ===
main() {
  local mounts
  mapfile -t mounts < <(get_physical_mounts)
  for t in "${extra_targets[@]}"; do
    local found=0
    for m in "${mounts[@]}"; do
      if [[ "$m" == "$t" ]]; then found=1; break; fi
    done
    [[ "$found" -eq 0 ]] && mounts+=("$t")
  done

  if [[ ${#mounts[@]} -eq 0 ]]; then
    mounts=("/")
  fi

  # --- Initial usage ---
  if [[ "$quiet" -eq 0 ]]; then
    echo -e "${BOLD}Disk usage before cleanup:${NC}"
    show_disk_usage "${mounts[@]}"
  fi

  # Snapshot all mounts
  for m in "${mounts[@]}"; do take_snapshot "$m"; done

  any_failed=0

  # --- 1. System Nix GC ---
  if confirm "Clean system Nix profiles?"; then
    ensure_sudo
    if [[ "$dry_run" -eq 1 ]]; then
      clean_nix_generations "/nix/var/nix/profiles/system" "sudo" "System"
    else
      local sys_mount="/"
      for m in "${mounts[@]}"; do
        if df "$m" 2>/dev/null | grep -q "/nix"; then sys_mount="$m"; break; fi
      done
      echo; log_header "System Nix GC"
      if [[ "$keep" -gt 0 ]]; then
        sudo nix-env --delete-generations +$keep -p /nix/var/nix/profiles/system >"$log_file" 2>&1 && log_ok || { log_fail; any_failed=1; }
      else
        sudo nix-collect-garbage -d >"$log_file" 2>&1 && log_ok || { log_fail; any_failed=1; }
      fi
      local after; after=$(df --output=avail "$sys_mount" 2>/dev/null | tail -1) || after=0
      local diff=$(( after - _fs_before["$sys_mount"] ))
      [[ $diff -gt 0 ]] && log_freed "$(human_size $(( diff * 1024 )))"
    fi
  fi

  # --- 2. User Nix GC ---
  if confirm "Clean user Nix profiles?"; then
    if [[ "$dry_run" -eq 1 ]]; then
      clean_nix_generations "" "" "User"
    else
      local user_mount="/home"
      for m in "${mounts[@]}"; do
        if echo "$HOME" | grep -q "^$m"; then user_mount="$m"; break; fi
      done
      echo; log_header "User Nix GC"
      if [[ "$keep" -gt 0 ]]; then
        nix-env --delete-generations +$keep >"$log_file" 2>&1 && log_ok || { log_fail; any_failed=1; }
      else
        nix-collect-garbage -d >"$log_file" 2>&1 && log_ok || { log_fail; any_failed=1; }
      fi
      local after; after=$(df --output=avail "$user_mount" 2>/dev/null | tail -1) || after=0
      local diff=$(( after - _fs_before["$user_mount"] ))
      [[ $diff -gt 0 ]] && log_freed "$(human_size $(( diff * 1024 )))"
    fi
    # Collect garbage if we manually deleted generations
    if [[ "$dry_run" -eq 0 && "$keep" -gt 0 ]]; then
      ensure_sudo
      run_step "Collect garbage" "" sudo nix-collect-garbage || true
    fi
  fi

  # --- 3. Nix store optimise ---
  if confirm "Run Nix store optimization (hard-link dedup)?"; then
    ensure_sudo
    local nix_mount="/"
    for m in "${mounts[@]}"; do
      df "$m" 2>/dev/null | grep -q "/nix" && { nix_mount="$m"; break; } || true
    done
    run_step "Nix store optimise" "$nix_mount" sudo nix store optimise || any_failed=1
  fi

  # --- 4. Journal vacuum ---
  if confirm "Vacuum systemd journal older than ${journal_days} days?"; then
    ensure_sudo
    local log_mount="/"
    for m in "${mounts[@]}"; do
      df "$m" 2>/dev/null | grep -q "/var/log" && { log_mount="$m"; break; } || true
    done
    run_step "Journal vacuum (${journal_days}d)" "$log_mount" sudo journalctl --vacuum-time="${journal_days}d" || any_failed=1
  fi

  # --- 5. Trash on all physical mounts ---
  for mnt in "${mounts[@]}"; do
    local trash_dir="$mnt/.Trash-$(id -u)"
    if [[ -d "$trash_dir" ]]; then
      if confirm "Clean Trash on ${mnt}?"; then
        run_step "Trash on ${mnt}" "$mnt" rm -rf "${trash_dir}/files" "${trash_dir}/info" "${trash_dir}/expunged" 2>/dev/null || true
      fi
    fi
  done

  # --- 6. Docker ---
  if [[ "$with_docker" -eq 1 ]]; then
    if command -v docker &>/dev/null; then
      if confirm "Run docker system prune (images, containers, volumes)?"; then
        ensure_sudo
        local docker_mount="/"
        for m in "${mounts[@]}"; do
          docker info 2>/dev/null | grep -q "Docker Root Dir: $m" && { docker_mount="$m"; break; } || true
        done
        run_step "Docker prune" "$docker_mount" sudo docker system prune -af || any_failed=1
      fi
    else
      log_warn "Docker not found, skipping."
    fi
  fi

  # === Aggressive steps ===
  if [[ "$aggressive" -eq 1 ]]; then

    # --- 7. Home-manager GC ---
    if confirm "Clean old home-manager generations (keep last ${keep:-1})?"; then
      local hm_profile="${HOME}/.local/state/nix/profiles/home-manager"
      if [[ -d "$(dirname "$hm_profile")" ]]; then
        if [[ "$dry_run" -eq 1 ]]; then
          local hm_count=$(nix-env --list-generations -p "$hm_profile" 2>/dev/null | wc -l) || hm_count=0
          log_header "Home-manager GC (dry-run)"
          echo "  would delete: $(( hm_count > 0 ? hm_count - 1 : 0 )) old generations"
        else
          local hm_mount="/home"
          for m in "${mounts[@]}"; do
            echo "$HOME" | grep -q "^$m" && { hm_mount="$m"; break; } || true
          done
          echo; log_header "Home-manager GC"
          if [[ "$keep" -gt 0 ]]; then
            nix-env --delete-generations +$keep -p "$hm_profile" >"$log_file" 2>&1 && log_ok || { log_fail "no home-manager profile found"; }
          else
            nix-collect-garbage -d >"$log_file" 2>&1 && log_ok || { log_fail "no home-manager profile found"; }
          fi
          local after; after=$(df --output=avail "$hm_mount" 2>/dev/null | tail -1) || after=0
          local diff=$(( after - _fs_before["$hm_mount"] ))
          [[ $diff -gt 0 ]] && log_freed "$(human_size $(( diff * 1024 )))"
        fi
      fi
    fi

    # --- 8. Flatpak ---
    if command -v flatpak &>/dev/null; then
      if confirm "Clean unused Flatpak runtimes?"; then
        run_step "Flatpak unused runtimes" "" flatpak uninstall --unused -y 2>/dev/null || true
      fi
    fi

    # --- 9. Go cache ---
    if command -v go &>/dev/null; then
      if confirm "Clean Go build cache?"; then
        local go_mount="/home"
        for m in "${mounts[@]}"; do
          echo "$HOME" | grep -q "^$m" && { go_mount="$m"; break; } || true
        done
        run_step "Go cache" "$go_mount" go clean -cache || true
      fi
    fi

    # --- 10. npm cache ---
    if command -v npm &>/dev/null; then
      if confirm "Clean npm cache?"; then
        local npm_mount="/home"
        for m in "${mounts[@]}"; do
          echo "$HOME" | grep -q "^$m" && { npm_mount="$m"; break; } || true
        done
        run_step "npm cache" "$npm_mount" npm cache clean --force || true
      fi
    fi

    # --- 11. Thumbnails ---
    if [[ -d "$HOME/.cache/thumbnails" ]]; then
      if confirm "Delete cached thumbnails?"; then
        local thumb_mount="/home"
        for m in "${mounts[@]}"; do
          echo "$HOME" | grep -q "^$m" && { thumb_mount="$m"; break; } || true
        done
        run_step "Thumbnail cache" "$thumb_mount" rm -rf "$HOME/.cache/thumbnails/"* 2>/dev/null || true
      fi
    fi

    # --- 12. Home Trash ---
    if [[ -d "$HOME/.local/share/Trash" ]]; then
      if confirm "Empty home trash?"; then
        local trash_mount="/home"
        for m in "${mounts[@]}"; do
          echo "$HOME" | grep -q "^$m" && { trash_mount="$m"; break; } || true
        done
        run_step "Home Trash" "$trash_mount" rm -rf "$HOME/.local/share/Trash/"* 2>/dev/null || true
      fi
    fi

    # --- 13. /tmp/nix-build-* ---
    if ls /tmp/nix-build-* &>/dev/null; then
      if confirm "Remove stale nix build directories in /tmp?"; then
        ensure_sudo
        local tmp_mount=""
        for m in "${mounts[@]}"; do
          df /tmp 2>/dev/null | grep -q "$m" && { tmp_mount="$m"; break; } || true
        done
        run_step "Nix build temp" "$tmp_mount" sudo rm -rf /tmp/nix-build-* 2>/dev/null || true
      fi
    fi

    # --- 14. Btrfs balance ---
    if command -v btrfs &>/dev/null; then
      for m in "${mounts[@]}"; do
        local fstype
        fstype=$(findmnt -n -o FSTYPE "$m" 2>/dev/null) || continue
        if [[ "$fstype" != "btrfs" ]]; then continue; fi
        local pcent
        pcent=$(df --output=pcent "$m" 2>/dev/null | tail -1 | tr -d ' %') || continue
        if [[ "$pcent" -ge 80 && "$pcent" -le 95 ]]; then
          if confirm "Run btrfs balance on ${m} (${pcent}% full)?"; then
            ensure_sudo
            echo; log_header "Btrfs balance ${m} (${pcent}%)"
            log_warn "This may take a while..."
            run_step "  balance -dusage=5" "$m" sudo btrfs balance start -dusage=5 "$m" || true
          fi
        elif [[ "$pcent" -gt 95 ]]; then
          log_warn "Skipping btrfs balance on ${m} (${pcent}% — disk too full, balance may be unsafe)"
        fi
      done
    fi

  fi

  # --- Final summary ---
  if [[ "$quiet" -eq 0 ]]; then
    echo
    echo -e "${BOLD}Disk usage after cleanup:${NC}"
    show_disk_usage "${mounts[@]}"
    echo
    echo -e "${BOLD}Freed space summary:${NC}"
    local total_freed=0
    for m in "${mounts[@]}"; do
      local diff
      diff=$(get_freed "$m")
      if [[ $diff -gt 0 ]]; then
        local freed_bytes=$(( diff * 1024 ))
        total_freed=$(( total_freed + freed_bytes ))
        echo -e "  ${GREEN}$m:${NC} ${YELLOW}$(human_size $freed_bytes)${NC}"
      fi
    done
    echo
    if [[ "$total_freed" -gt 0 ]]; then
      echo -e "  ${BOLD}Total freed:${NC} ${GREEN}$(human_size $total_freed)${NC}"
    else
      echo -e "  ${BOLD}Total freed:${NC} nothing"
    fi
  fi

  # --- Desktop notification ---
  if ! [[ -t 1 ]] && command -v notify-send &>/dev/null && [[ -n "${DISPLAY:-}" ]]; then
    local summary=""
    local total_freed_n=0
    for m in "${mounts[@]}"; do
      local d; d=$(get_freed "$m"); total_freed_n=$(( total_freed_n + d ))
    done
    local freed_hr; freed_hr=$(human_size $(( total_freed_n * 1024 )))
    if [[ "$dry_run" -eq 1 ]]; then
      notify-send "Disk Clean (dry-run)" "No changes made\nWould free: ${freed_hr}"
    elif [[ "$any_failed" -eq 1 ]]; then
      notify-send -u critical "Disk Clean" "⚠ Some steps failed\nFreed: ${freed_hr}"
    else
      notify-send "Disk Clean" "✓ Cleanup complete\nFreed: ${freed_hr}"
    fi
  fi
}

main "$@"
