{ pkgs, ... }:

let
  vmName = "docker-host";
  windowsBridgeAdapter = "Realtek Gaming 2.5GbE Family Controller";
  windowsHostOnlyAdapter = "VirtualBox Host-Only Ethernet Adapter";
  vbm = "/run/current-system/sw/bin/VBoxManage";
  logFile = ''"$HOME/.local/state/${vmName}.log"'';

  dockerHostVm = pkgs.writeShellScriptBin "docker-host-vm" ''
    set -euo pipefail

    vm_name="${vmName}"
    windows_bridge_adapter="${windowsBridgeAdapter}"
    windows_host_only_adapter="${windowsHostOnlyAdapter}"
    log=${logFile}

    mkdir -p "$(dirname "$log")"

    log_msg() {
      printf '%s %s\n' "$(date -Is)" "$*" >> "$log"
    }

    running() {
      ${vbm} list runningvms | ${pkgs.gnugrep}/bin/grep -Fq "\"$vm_name\""
    }

    vm_state() {
      ${vbm} showvminfo "$vm_name" --machinereadable \
        | ${pkgs.gnused}/bin/sed -n 's/^VMState="\([^"]*\)"/\1/p'
    }

    current_bridge_adapter() {
      ${vbm} showvminfo "$vm_name" --machinereadable \
        | ${pkgs.gnused}/bin/sed -n 's/^bridgeadapter1="\([^"]*\)"/\1/p'
    }

    current_host_only_adapter() {
      ${vbm} showvminfo "$vm_name" --machinereadable \
        | ${pkgs.gnused}/bin/sed -n 's/^hostonlyadapter2="\([^"]*\)"/\1/p'
    }

    linux_default_interface() {
      ${pkgs.iproute2}/bin/ip -o route show default \
        | ${pkgs.gawk}/bin/awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
    }

    bridge_exists() {
      adapter="$1"
      ${vbm} list bridgedifs \
        | ${pkgs.gnugrep}/bin/grep -Fxq "Name:            $adapter"
    }

    host_only_exists() {
      adapter="$1"
      ${vbm} list hostonlyifs \
        | ${pkgs.gnugrep}/bin/grep -Fxq "Name:            $adapter"
    }

    set_bridge_adapter() {
      adapter="$1"
      if [ -n "$adapter" ] && [ "$(current_bridge_adapter)" != "$adapter" ]; then
        log_msg "setting bridgeadapter1 to '$adapter'"
        ${vbm} modifyvm "$vm_name" --nic1 bridged --bridgeadapter1 "$adapter"
      fi
    }

    set_host_only_adapter() {
      adapter="$1"
      if [ -n "$adapter" ] && [ "$(current_host_only_adapter)" != "$adapter" ]; then
        log_msg "setting hostonlyadapter2 to '$adapter'"
        ${vbm} modifyvm "$vm_name" --nic2 hostonly --hostonlyadapter2 "$adapter"
      fi
    }

    repair_linux_bridge_adapter() {
      current="$(current_bridge_adapter)"
      if bridge_exists "$current"; then
        log_msg "bridgeadapter1 '$current' exists"
        return 0
      fi

      linux_adapter="$(linux_default_interface)"
      if [ -z "$linux_adapter" ]; then
        log_msg "no default route interface found"
        return 1
      fi

      if ! bridge_exists "$linux_adapter"; then
        log_msg "default route interface '$linux_adapter' is not available to VirtualBox"
        return 1
      fi

      log_msg "bridgeadapter1 '$current' is unavailable on Linux; using '$linux_adapter'"
      set_bridge_adapter "$linux_adapter"
    }

    restore_windows_bridge_adapter() {
      set_bridge_adapter "$windows_bridge_adapter"
    }

    repair_linux_host_only_adapter() {
      current="$(current_host_only_adapter)"
      if host_only_exists "$current"; then
        log_msg "hostonlyadapter2 '$current' exists"
        return 0
      fi

      if host_only_exists "vboxnet0"; then
        log_msg "hostonlyadapter2 '$current' is unavailable on Linux; using 'vboxnet0'"
        set_host_only_adapter "vboxnet0"
        return 0
      fi

      log_msg "no Linux host-only adapter found for nic2"
      return 1
    }

    restore_windows_host_only_adapter() {
      set_host_only_adapter "$windows_host_only_adapter"
    }

    repair_linux_network() {
      repair_linux_bridge_adapter
      repair_linux_host_only_adapter
    }

    restore_windows_network() {
      restore_windows_bridge_adapter
      restore_windows_host_only_adapter
    }

    discard_stale_saved_state() {
      state="$(vm_state)"
      case "$state" in
        saved|aborted-saved)
          log_msg "discarding stale saved state '$state' before headless start"
          ${vbm} discardstate "$vm_name" >> "$log" 2>&1
          ;;
      esac
    }

    start_vm() {
      {
        log_msg "start requested"
        log_msg "groups: $(id -nG)"
        ${pkgs.coreutils}/bin/stat -c '%n %a %U %G %g' /dev/vboxdrv /dev/vboxdrvu >> "$log" 2>&1 || true

        if running; then
          log_msg "$vm_name already running"
          exit 0
        fi

        repair_linux_network
        discard_stale_saved_state
        ${vbm} startvm "$vm_name" --type headless >> "$log" 2>&1
      } >> "$log" 2>&1
    }

    stop_vm() {
      {
        log_msg "stop requested"
        if running; then
          ${vbm} controlvm "$vm_name" acpipowerbutton >> "$log" 2>&1

          for _ in $(seq 1 60); do
            state="$(vm_state)"
            if [ "$state" = "poweroff" ]; then
              restore_windows_network
              exit 0
            fi
            sleep 2
          done

          log_msg "$vm_name did not stop within timeout"
          exit 1
        fi

        restore_windows_network
      } >> "$log" 2>&1
    }

    case "''${1:-start}" in
      start) start_vm ;;
      stop) stop_vm ;;
      status) vm_state ;;
      discard-state) discard_stale_saved_state ;;
      repair-network) repair_linux_network ;;
      restore-windows-network) restore_windows_network ;;
      *)
        echo "Usage: docker-host-vm {start|stop|status|discard-state|repair-network|restore-windows-network}" >&2
        exit 64
        ;;
    esac
  '';
in
{
  home.packages = [
    dockerHostVm
  ];

  systemd.user.services.virtualbox-docker-host = {
    Unit = {
      Description = "Autostart docker-host VirtualBox VM";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [
        "VBOX_USER_HOME=%h/.config/VirtualBox"
      ];
      ExecStart = "${dockerHostVm}/bin/docker-host-vm start";
      ExecStop = "${dockerHostVm}/bin/docker-host-vm stop";
      TimeoutStartSec = "120s";
      TimeoutStopSec = "150s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
