{ pkgs, ... }:

let
  vmName = "docker-host";
  windowsBridgeAdapter = "Realtek Gaming 2.5GbE Family Controller";
  windowsHostOnlyAdapter = "VirtualBox Host-Only Ethernet Adapter";
  linuxHostOnlyAdapter = "vboxnet0";
  linuxHostOnlyAddress = "192.168.56.1";
  linuxHostOnlyMask = "255.255.255.0";
  linuxGuestAddress = "192.168.56.101";
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

    host_only_ip_address() {
      adapter="$1"
      ${vbm} list hostonlyifs \
        | ${pkgs.gawk}/bin/awk -v adapter="$adapter" '
            $1 == "Name:" && $2 == adapter { found = 1; next }
            found && $1 == "IPAddress:" { print $2; exit }
            found && $1 == "Name:" { exit }
          '
    }

    host_only_network_mask() {
      adapter="$1"
      ${vbm} list hostonlyifs \
        | ${pkgs.gawk}/bin/awk -v adapter="$adapter" '
            $1 == "Name:" && $2 == adapter { found = 1; next }
            found && $1 == "NetworkMask:" { print $2; exit }
            found && $1 == "Name:" { exit }
          '
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

    ensure_host_only_address() {
      adapter="$1"
      address="${linuxHostOnlyAddress}"
      mask="${linuxHostOnlyMask}"

      current_address="$(host_only_ip_address "$adapter")"
      current_mask="$(host_only_network_mask "$adapter")"

      if [ "$current_address" != "$address" ] || [ "$current_mask" != "$mask" ]; then
        log_msg "configuring $adapter as $address/$mask"
        ${vbm} hostonlyif ipconfig "$adapter" --ip "$address" --netmask "$mask"
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
        if [ "$current" = "${linuxHostOnlyAdapter}" ]; then
          ensure_host_only_address "${linuxHostOnlyAdapter}"
        fi
        log_msg "hostonlyadapter2 '$current' exists"
        return 0
      fi

      if host_only_exists "${linuxHostOnlyAdapter}"; then
        log_msg "hostonlyadapter2 '$current' is unavailable on Linux; using '${linuxHostOnlyAdapter}'"
        ensure_host_only_address "${linuxHostOnlyAdapter}"
        set_host_only_adapter "${linuxHostOnlyAdapter}"
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

    network_status() {
      echo "VM: $vm_name"
      echo "State: $(vm_state)"
      echo "Bridge adapter: $(current_bridge_adapter)"
      echo "Host-only adapter: $(current_host_only_adapter)"
      echo "Host-only host IP: ${linuxHostOnlyAddress}"
      echo "Expected guest IP: ${linuxGuestAddress}"
      echo
      ${vbm} list hostonlyifs \
        | ${pkgs.gnused}/bin/sed -n '/^Name: *${linuxHostOnlyAdapter}$/,/^$/p'
      echo
      if ${pkgs.coreutils}/bin/timeout 2 ${pkgs.bash}/bin/bash -c "</dev/tcp/${linuxHostOnlyAddress}/10808" >/dev/null 2>&1; then
        echo "open ${linuxHostOnlyAddress}:10808 host proxy"
      else
        echo "closed ${linuxHostOnlyAddress}:10808 host proxy"
      fi
      echo
      for port in 22 80 443 8000 8080 3000 5173; do
        if ${pkgs.coreutils}/bin/timeout 2 ${pkgs.bash}/bin/bash -c "</dev/tcp/${linuxGuestAddress}/$port" >/dev/null 2>&1; then
          echo "open ${linuxGuestAddress}:$port"
        else
          echo "closed ${linuxGuestAddress}:$port"
        fi
      done
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
      start_complete=0

      restore_on_start_failure() {
        status=$?
        trap - ERR
        if [ "$start_complete" -eq 0 ]; then
          log_msg "start failed; restoring Windows network adapters"
          restore_windows_network || true
        fi
        exit "$status"
      }

      trap restore_on_start_failure ERR

      {
        log_msg "start requested"
        log_msg "groups: $(id -nG)"
        ${pkgs.coreutils}/bin/stat -c '%n %a %U %G %g' /dev/vboxdrv /dev/vboxdrvu >> "$log" 2>&1 || true

        if running; then
          log_msg "$vm_name already running"
          start_complete=1
          trap - ERR
          return 0
        fi

        repair_linux_network
        discard_stale_saved_state
        ${vbm} startvm "$vm_name" --type headless >> "$log" 2>&1
        start_complete=1
        trap - ERR
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

    monitor_vm() {
      start_vm

      trap 'log_msg "monitor stopped"; stop_vm; exit 0' TERM INT

      while true; do
        if ! running; then
          log_msg "$vm_name stopped while monitored"
          exit 1
        fi
        sleep 30
      done
    }

    case "''${1:-start}" in
      start) start_vm ;;
      monitor) monitor_vm ;;
      stop) stop_vm ;;
      status) vm_state ;;
      network-status) network_status ;;
      discard-state) discard_stale_saved_state ;;
      repair-network) repair_linux_network ;;
      restore-windows-network) restore_windows_network ;;
      *)
        echo "Usage: docker-host-vm {start|monitor|stop|status|network-status|discard-state|repair-network|restore-windows-network}" >&2
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
      Type = "simple";
      Environment = [
        "VBOX_USER_HOME=%h/.config/VirtualBox"
      ];
      ExecStart = "${dockerHostVm}/bin/docker-host-vm monitor";
      ExecStop = "${dockerHostVm}/bin/docker-host-vm stop";
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "120s";
      TimeoutStopSec = "150s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

}
