{
  config,
  lib,
  pkgs,
  ...
}:

{
  systemd.services."scheduled-auto-accrue-interest" = {
    description = "Automatic interest accrual";
    serviceConfig = {
      Type = "oneshot";
      User = "snrx";
      WorkingDirectory = "/home/snrx/nixos/scripts/payments-cli/scripts";
      ExecStart = "${pkgs.bash}/bin/bash /home/snrx/nixos/scripts/payments-cli/scripts/auto-accrue-interest.sh";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    environment = {
      HOME = "/home/snrx";
      USER = "snrx";
      SCRIPT_DIR = "/home/snrx/nixos/scripts/payments-cli/scripts";
      LEDGER_PATH = "/home/snrx/ObsidianVault/finances/transactions.ledger";
    };
    path = with pkgs; [
      bash
      coreutils
    ];
  };

  systemd.timers."scheduled-auto-accrue-interest" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "09:00";
      Persistent = true;
    };
  };
}
