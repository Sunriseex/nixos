{ pkgs, ... }:

let
  vmName = "docker-host";
  vbm = "${pkgs.virtualbox}/bin/VBoxManage";

  startVm = pkgs.writeShellScript "hm-virtualbox-start-${vmName}" ''
    set -euo pipefail

    if ! ${vbm} list runningvms | ${pkgs.gnugrep}/bin/grep -Fq "\"${vmName}\""; then
      exec ${vbm} startvm "${vmName}" --type headless
    fi
  '';

  stopVm = pkgs.writeShellScript "hm-virtualbox-stop-${vmName}" ''
    set -euo pipefail

    if ${vbm} list runningvms | ${pkgs.gnugrep}/bin/grep -Fq "\"${vmName}\""; then
      ${vbm} controlvm "${vmName}" acpipowerbutton
    fi
  '';
in
{
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
      ExecStart = "${startVm}";
      ExecStop = "${stopVm}";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
