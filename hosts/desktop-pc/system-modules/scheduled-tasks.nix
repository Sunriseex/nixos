{
  pkgs,
  ...
}:
let
  deposit-manager = import ../../../scripts/payments-cli/default.nix { inherit pkgs; };
in
{
  systemd.services."scheduled-auto-accrue-interest" = {
    description = "Automatic interest accrual";
    serviceConfig = {
      Type = "oneshot";
      User = "snrx";
      WorkingDirectory = "/home/snrx";
      ExecStart = "${pkgs.bash}/bin/bash /home/snrx/nixos/scripts/payments-cli/scripts/auto-accrue-interest.sh";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    environment = {
      HOME = "/home/snrx";
      USER = "snrx";
    };
    path = with pkgs; [
      bash
      coreutils
      bc
      jq
      deposit-manager
    ];
  };

  systemd.timers."scheduled-auto-accrue-interest" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
    };
  };
}
