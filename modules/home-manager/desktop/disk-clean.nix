{ pkgs, ... }:

{
  systemd.user.services.disk-clean-weekly = {
    Unit = {
      Description = "Weekly disk cleanup — nix GC, journal, docker, caches";
      Documentation = "https://github.com/snrx/nixos";
    };

    Service = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c '${pkgs.bash}/bin/bash ~/.local/bin/disk-cleanup.sh --yes --docker --aggressive --quiet 2>&1 | ${pkgs.systemd}/bin/systemd-cat -t disk-cleanup'
      '';
      Environment = "PATH=/run/wrappers/bin:/run/current-system/sw/bin:${pkgs.libnotify}/bin";
      Nice = 19;
    };
  };

  systemd.user.timers.disk-clean-weekly = {
    Unit = {
      Description = "Weekly disk cleanup timer";
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
