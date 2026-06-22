{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.programs.calendar;
  secretsDir = "$HOME/.config/calendar-secrets";
  calendarDir = "$HOME/.calendars";
  vdirsyncerConfigDir = "$HOME/.config/vdirsyncer";

  syncScript = pkgs.writeShellApplication {
    name = "calendar-sync";
    runtimeInputs = with pkgs; [ vdirsyncer ];
    text = ''
      set -euo pipefail

      email_file="${secretsDir}/icloud-email"
      pass_file="${secretsDir}/icloud-app-password"

      if [ ! -f "$email_file" ] || [ ! -f "$pass_file" ]; then
        echo "calendar-sync: iCloud secrets not found." >&2
        echo "Place email in ${secretsDir}/icloud-email and password in ${secretsDir}/icloud-app-password" >&2
        exit 1
      fi

      email="$(cat "$email_file")"
      pass="$(cat "$pass_file")"

      mkdir -p "${vdirsyncerConfigDir}"
      cat > "${vdirsyncerConfigDir}/config" <<- VDIRSYNCER_EOF
      [general]
      status_path = "${config.xdg.dataHome}/vdirsyncer/status/"

      [pair icloud_to_local]
      a = "icloud_local"
      b = "icloud_remote"
      collections = ["from a", "from b"]
      conflict_resolution = "a wins"

      [storage icloud_local]
      type = "filesystem"
      path = "${calendarDir}/icloud/"
      fileext = ".ics"

      [storage icloud_remote]
      type = "caldav"
      url = "https://caldav.icloud.com/"
      username = "$email"
      password = "$pass"
VDIRSYNCER_EOF

      mkdir -p "${calendarDir}/icloud" "${config.xdg.dataHome}/vdirsyncer/status/"
      exec vdirsyncer sync
    '';
  };

  calendarShow = pkgs.writeShellApplication {
    name = "calendar-show";
    runtimeInputs = with pkgs; [ khal ];
    text = ''
      exec khal calendar "$@"
    '';
  };

  calendarAgenda = pkgs.writeShellApplication {
    name = "calendar-agenda";
    runtimeInputs = with pkgs; [ khal ];
    text = ''
      exec khal agenda --days 7
    '';
  };
in
{
  options.programs.calendar = {
    enable = lib.mkEnableOption "iCloud calendar sync (vdirsyncer + khal)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      vdirsyncer
      khal
      syncScript
      calendarShow
      calendarAgenda
    ];

    home.file = {
      ".config/khal/config".text = ''
        [calendars]
        [[icloud]]
        path = ${calendarDir}/icloud/
        color = apple_blue
        read_only = true

        [locale]
        timeformat = %H:%M
        dateformat = %Y-%m-%d
        longdateformat = %Y-%m-%d
        firstweekday = 1
        weeknumbers = off

        [default]
        default_calendar = icloud

        [keybindings]
      '';

      "${secretsDir}/.gitkeep".text = ''
        Place your iCloud email in 'icloud-email' and app password in 'icloud-app-password'.
        Then run: systemctl --user start vdirsyncer
      '';
    };

    systemd.user.services.vdirsyncer = {
      Unit = {
        Description = "vdirsyncer iCloud calendar sync";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}/bin/calendar-sync";
      };
    };

    systemd.user.timers.vdirsyncer = {
      Unit = {
        Description = "Periodic iCloud calendar sync";
      };
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "15min";
        RandomizedDelaySec = "30";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
