{
  config,
  pkgs,
  ...
}:
let
  serviceUser = "snrx";
  serviceHome = config.users.users.${serviceUser}.home;
  deposit-manager = import ../../../scripts/finance-manager/default.nix { inherit pkgs; };
in
{
  systemd.services."scheduled-auto-accrue-interest" = {
    description = "Automatic interest accrual";
    serviceConfig = {
      Type = "oneshot";
      User = serviceUser;
      WorkingDirectory = serviceHome;
      ExecStart = "${deposit-manager}/bin/deposit-manager accrue-interest";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    environment = {
      HOME = serviceHome;
      USER = serviceUser;
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
