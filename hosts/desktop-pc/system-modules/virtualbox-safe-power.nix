{ pkgs, ... }:

let
  vmName = "docker-host";
  vbm = "${pkgs.virtualbox}/bin/VBoxManage";

  waitForVmShutdown = ''
    if ${vbm} list runningvms | grep -Fq "\"${vmName}\""; then
      echo "Sending ACPI shutdown to ${vmName}..."
      ${vbm} controlvm "${vmName}" acpipowerbutton

      stopped=0
      for _ in $(seq 1 60); do
        state="$(${vbm} showvminfo "${vmName}" --machinereadable | sed -n 's/^VMState="\([^"]*\)"/\1/p')"
        if [ "$state" = "poweroff" ]; then
          stopped=1
          break
        fi
        sleep 2
      done

      if [ "$stopped" -ne 1 ]; then
        echo "VM ${vmName} did not stop in time. Host action aborted."
        exit 1
      fi
    fi
  '';
in
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "safe-reboot" ''
      set -euo pipefail
      ${waitForVmShutdown}
      exec systemctl reboot
    '')

    (pkgs.writeShellScriptBin "safe-poweroff" ''
      set -euo pipefail
      ${waitForVmShutdown}
      exec systemctl poweroff
    '')
  ];
}
