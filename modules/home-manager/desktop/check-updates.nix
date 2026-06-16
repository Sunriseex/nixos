{ pkgs, ... }:

{
  systemd.user.services.check-poe-updates = {
    Unit = {
      Description = "Check for PoE app updates on GitHub";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${../../../scripts/check-poe-updates.sh}";
      Environment = "PATH=${pkgs.curl}/bin:${pkgs.gnused}/bin:${pkgs.libnotify}/bin";
      Nice = 19;
    };
  };

  systemd.user.timers.check-poe-updates = {
    Unit = {
      Description = "Weekly check for PoE app updates";
    };

    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
