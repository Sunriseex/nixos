{ pkgs, ... }:

{
  systemd.user.services.poe-weekly-news = {
    Unit = {
      Description = "Weekly PoE news digest → Obsidian + Telegram";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${../../../scripts/poe-weekly-news.sh}";
      Environment = "PATH=${pkgs.opencode}/bin:${pkgs.curl}/bin:${pkgs.coreutils}/bin";
      Nice = 19;
    };
  };

  systemd.user.timers.poe-weekly-news = {
    Unit = {
      Description = "Weekly PoE news timer";
    };

    Timer = {
      OnCalendar = "Mon 12:00:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
