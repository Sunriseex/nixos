{ pkgs, ... }:

let
  codexLimitRingsStatus = pkgs.writeShellApplication {
    name = "codex-limit-rings-status";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      gnused
      sqlite
    ];
    text = ''
      set -euo pipefail

      mode="''${1:-summary}"
      codex_home="''${CODEX_HOME:-$HOME/.codex}"
      auth_file="$codex_home/auth.json"
      logs_file="$codex_home/logs_2.sqlite"

      clamp_remaining() {
        awk '{
          value = 100 - $1
          if (value < 0) value = 0
          if (value > 100) value = 100
          printf "%.0f", value
        }'
      }

      live_usage() {
        [ -r "$auth_file" ] || return 1
        token="$(jq -r '.tokens.access_token // empty' "$auth_file")"
        [ -n "$token" ] || return 1

        curl --fail --silent --show-error --max-time 4 \
          -H "Authorization: Bearer $token" \
          -H "Accept: application/json" \
          "https://chatgpt.com/backend-api/wham/usage"
      }

      cached_usage() {
        [ -r "$logs_file" ] || return 1
        sqlite3 "$logs_file" \
          "SELECT feedback_log_body FROM logs WHERE feedback_log_body LIKE '%\"type\":\"codex.rate_limits\"%' ORDER BY ts DESC, ts_nanos DESC, id DESC LIMIT 1;" \
          | sed -n 's/.*\({\"type\":\"codex.rate_limits\".*\)$/\1/p'
      }

      read_usage() {
        if payload="$(live_usage 2>/dev/null)" && [ -n "$payload" ]; then
          source="Live"
          primary_filter='(.rate_limit.primary // .rate_limit.primary_window).used_percent // empty'
          secondary_filter='(.rate_limit.secondary // .rate_limit.secondary_window).used_percent // empty'
        elif payload="$(cached_usage 2>/dev/null)" && [ -n "$payload" ]; then
          source="Cached"
          primary_filter='(.rate_limits.primary // .rate_limits.primary_window).used_percent // empty'
          secondary_filter='(.rate_limits.secondary // .rate_limits.secondary_window).used_percent // empty'
        else
          source="No data"
          payload="{}"
          primary_filter='empty'
          secondary_filter='empty'
        fi

        primary_used="$(jq -r "$primary_filter" <<<"$payload" 2>/dev/null || true)"
        secondary_used="$(jq -r "$secondary_filter" <<<"$payload" 2>/dev/null || true)"
        primary="0"
        secondary="0"

        if [ -n "$primary_used" ] && [ "$primary_used" != "null" ]; then
          primary="$(printf '%s\n' "$primary_used" | clamp_remaining)"
        fi

        if [ -n "$secondary_used" ] && [ "$secondary_used" != "null" ]; then
          secondary="$(printf '%s\n' "$secondary_used" | clamp_remaining)"
        fi
      }

      read_usage

      state="idle"
      if [ "$source" = "No data" ]; then
        state="waiting"
      elif [ "$primary" -le 10 ] || [ "$secondary" -le 10 ]; then
        state="failed"
      elif [ "$primary" -le 25 ] || [ "$secondary" -le 25 ]; then
        state="review"
      elif [ "$primary" -le 70 ] || [ "$secondary" -le 70 ]; then
        state="running"
      fi

      case "$mode" in
        primary) printf '%s\n' "$primary" ;;
        secondary) printf '%s\n' "$secondary" ;;
        source) printf '%s\n' "$source" ;;
        state) printf '%s\n' "$state" ;;
        summary) printf '%s%% / %s%% %s\n' "$primary" "$secondary" "$source" ;;
        *) printf 'usage: codex-limit-rings-status [primary|secondary|source|state|summary]\n' >&2; exit 2 ;;
      esac
    '';
  };

  codexLimitRingsService = pkgs.writeShellApplication {
    name = "codex-limit-rings-service";
    runtimeInputs = with pkgs; [
      coreutils
      eww
    ];
    text = ''
      set -euo pipefail

      config_dir="$HOME/.config/eww/codex-limit-rings"

      eww -c "$config_dir" daemon >/dev/null 2>&1 || true
      sleep 0.2
      eww -c "$config_dir" open codex-limit-rings || true

      trap 'eww -c "$config_dir" close codex-limit-rings >/dev/null 2>&1 || true' EXIT
      exec sleep infinity
    '';
  };

  macosStyleCss = ''
    /* Installed as an alternate theme only. The active GTK theme remains Nordic. */
    @define-color accent_color #0a84ff;
    @define-color accent_bg_color #0a84ff;
    @define-color accent_fg_color #ffffff;
    @define-color window_bg_color rgba(246, 247, 249, 0.92);
    @define-color window_fg_color #1d1d1f;
    @define-color headerbar_bg_color rgba(246, 247, 249, 0.86);
    @define-color headerbar_fg_color #1d1d1f;
    @define-color card_bg_color rgba(255, 255, 255, 0.72);
    @define-color card_fg_color #1d1d1f;

    * {
      font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", sans-serif;
      font-weight: 600;
      border-radius: 10px;
    }

    window,
    dialog,
    popover,
    menu {
      background-color: @window_bg_color;
      color: @window_fg_color;
    }

    headerbar,
    .titlebar {
      min-height: 38px;
      background-color: @headerbar_bg_color;
      color: @headerbar_fg_color;
      border-bottom: 1px solid rgba(60, 60, 67, 0.18);
    }

    button,
    entry,
    combobox,
    spinbutton,
    switch,
    notebook > header > tabs > tab {
      border-radius: 8px;
    }

    button.suggested-action,
    switch:checked {
      background: @accent_bg_color;
      color: @accent_fg_color;
    }
  '';
in
{
  home.packages = [
    pkgs.eww
    codexLimitRingsStatus
    codexLimitRingsService
  ];

  xdg.dataFile."themes/Sunrise-macOS/gtk-3.0/gtk.css".text = macosStyleCss;
  xdg.dataFile."themes/Sunrise-macOS/gtk-4.0/gtk.css".text = macosStyleCss;
  xdg.dataFile."themes/Sunrise-macOS/index.theme".text = ''
    [Desktop Entry]
    Type=X-GNOME-Metatheme
    Name=Sunrise-macOS
    Comment=macOS-style alternate theme; not activated by Home Manager.

    [X-GNOME-Metatheme]
    GtkTheme=Sunrise-macOS
    IconTheme=kora-pgrey
    CursorTheme=WhiteSur-cursors
  '';

  xdg.configFile."eww/codex-limit-rings/eww.yuck".text = ''
    (defpoll primary :interval "30s" "codex-limit-rings-status primary")
    (defpoll secondary :interval "30s" "codex-limit-rings-status secondary")
    (defpoll pet_state :interval "30s" "codex-limit-rings-status state")
    (defpoll summary :interval "30s" "codex-limit-rings-status summary")

    (defwidget hiyuki-pet []
      (box :class "pet-stage" :orientation "v"
        (box :class "hiyuki-pet ''${pet_state}"
          (box :class "pet-shadow")
          (box :class "pet-sword")
          (box :class "pet-body")
          (box :class "pet-head")
          (box :class "pet-hair hair-left")
          (box :class "pet-hair hair-right")
          (box :class "pet-ribbon ribbon-left")
          (box :class "pet-ribbon ribbon-right")
          (box :class "pet-flower")
          (box :class "pet-eye eye-left")
          (box :class "pet-eye eye-right")
          (box :class "pet-code code-a")
          (box :class "pet-code code-b")
          (box :class "pet-code code-c"))))

    (defwidget codex-limit-rings []
      (box :class "rings-wrap" :orientation "v" :spacing 9
        (hiyuki-pet)
        (overlay
          (circular-progress :class "outer-ring" :value primary :thickness 8 :start-at 75)
          (circular-progress :class "inner-ring" :value secondary :thickness 8 :start-at 75)
          (label :class "rings-mark" :text "Codex"))
        (label :class "rings-summary" :text summary)))

    (defwindow codex-limit-rings
      :monitor 0
      :geometry (geometry :x "24px" :y "96px" :width "184px" :height "286px" :anchor "top right")
      :stacking "fg"
      :focusable false
      :exclusive false
      (codex-limit-rings))
  '';

  xdg.configFile."eww/codex-limit-rings/eww.scss".text = ''
    * {
      all: unset;
      font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", sans-serif;
      font-weight: 600;
    }

    .rings-wrap {
      padding: 14px;
      border-radius: 20px;
      background: rgba(246, 247, 249, 0.78);
      border: 1px solid rgba(255, 255, 255, 0.62);
      box-shadow: 0 14px 42px rgba(0, 0, 0, 0.26);
      color: #1d1d1f;
    }

    .pet-stage {
      min-width: 156px;
      min-height: 112px;
    }

    .hiyuki-pet {
      min-width: 156px;
      min-height: 112px;
      animation: pet-idle 2.6s ease-in-out infinite;
    }

    .hiyuki-pet.running {
      animation: pet-running 0.72s steps(2, end) infinite;
    }

    .hiyuki-pet.review {
      animation: pet-review 1.1s ease-in-out infinite;
    }

    .hiyuki-pet.waiting {
      animation: pet-waiting 1.9s ease-in-out infinite;
    }

    .hiyuki-pet.failed {
      animation: pet-failed 0.34s steps(2, end) infinite;
    }

    .pet-shadow {
      background: rgba(29, 29, 31, 0.18);
      border-radius: 999px;
      margin: 96px 38px 0 42px;
      min-width: 74px;
      min-height: 10px;
    }

    .pet-body {
      background: linear-gradient(180deg, #fff9fb 0%, #f4eff7 58%, #d9e7f8 100%);
      border: 2px solid rgba(75, 91, 122, 0.38);
      border-radius: 22px 22px 18px 18px;
      margin: 54px 52px 0 54px;
      min-width: 48px;
      min-height: 46px;
    }

    .pet-head {
      background: linear-gradient(180deg, #ffffff 0%, #edf5ff 100%);
      border: 2px solid rgba(75, 91, 122, 0.34);
      border-radius: 999px;
      margin: 16px 43px 0 45px;
      min-width: 64px;
      min-height: 56px;
    }

    .pet-hair {
      background: linear-gradient(180deg, #f8fdff 0%, #c9d9ee 100%);
      border: 1px solid rgba(92, 116, 147, 0.22);
      min-width: 36px;
      min-height: 38px;
    }

    .hair-left {
      border-radius: 22px 10px 20px 8px;
      margin: 11px 0 0 40px;
    }

    .hair-right {
      border-radius: 10px 22px 8px 20px;
      margin: 12px 0 0 78px;
    }

    .pet-ribbon {
      background: #d92d45;
      border: 1px solid rgba(92, 10, 28, 0.34);
      min-width: 17px;
      min-height: 28px;
    }

    .ribbon-left {
      border-radius: 11px 4px 12px 4px;
      margin: 35px 0 0 34px;
    }

    .ribbon-right {
      border-radius: 4px 11px 4px 12px;
      margin: 35px 0 0 105px;
    }

    .pet-flower {
      background: #ffffff;
      border: 3px solid #ffe5ed;
      border-radius: 999px;
      margin: 19px 0 0 96px;
      min-width: 20px;
      min-height: 20px;
    }

    .pet-eye {
      background: #cf1f3a;
      border-radius: 999px;
      min-width: 7px;
      min-height: 9px;
    }

    .eye-left {
      margin: 41px 0 0 62px;
    }

    .eye-right {
      margin: 41px 0 0 86px;
    }

    .pet-sword {
      background: linear-gradient(180deg, rgba(196, 245, 255, 0.0) 0%, rgba(92, 215, 255, 0.95) 18%, rgba(19, 118, 255, 0.95) 100%);
      border-radius: 999px;
      box-shadow: 0 0 14px rgba(10, 132, 255, 0.58);
      margin: 18px 0 0 118px;
      min-width: 8px;
      min-height: 80px;
      animation: sword-glow 1.7s ease-in-out infinite;
    }

    .pet-code {
      background: rgba(10, 132, 255, 0.62);
      border-radius: 999px;
      min-width: 5px;
      min-height: 5px;
      opacity: 0;
    }

    .code-a {
      margin: 28px 0 0 24px;
    }

    .code-b {
      margin: 54px 0 0 132px;
    }

    .code-c {
      margin: 76px 0 0 18px;
    }

    .hiyuki-pet.running .pet-code,
    .hiyuki-pet.review .pet-code,
    .hiyuki-pet.failed .pet-code {
      animation: code-mote 1.1s ease-in-out infinite;
    }

    .hiyuki-pet.review .pet-sword {
      background: linear-gradient(180deg, rgba(255, 214, 102, 0.0) 0%, rgba(255, 159, 10, 0.95) 22%, rgba(10, 132, 255, 0.9) 100%);
      box-shadow: 0 0 18px rgba(255, 159, 10, 0.7);
    }

    .hiyuki-pet.failed .pet-sword,
    .hiyuki-pet.failed .pet-eye {
      background: #ff453a;
      box-shadow: 0 0 18px rgba(255, 69, 58, 0.75);
    }

    .outer-ring {
      color: #34c759;
      background-color: rgba(60, 60, 67, 0.14);
      min-width: 118px;
      min-height: 118px;
    }

    .inner-ring {
      color: #0a84ff;
      background-color: rgba(60, 60, 67, 0.10);
      margin: 18px;
      min-width: 82px;
      min-height: 82px;
    }

    .rings-mark {
      color: #1d1d1f;
      font-size: 14px;
    }

    .rings-summary {
      color: #3c3c43;
      font-size: 12px;
    }

    @keyframes pet-idle {
      0% { margin-top: 0; }
      50% { margin-top: -3px; }
      100% { margin-top: 0; }
    }

    @keyframes pet-running {
      0% { margin-left: -2px; }
      50% { margin-left: 2px; }
      100% { margin-left: -2px; }
    }

    @keyframes pet-review {
      0% { margin-top: 0; }
      50% { margin-top: -5px; }
      100% { margin-top: 0; }
    }

    @keyframes pet-waiting {
      0% { opacity: 0.72; }
      50% { opacity: 1; }
      100% { opacity: 0.72; }
    }

    @keyframes pet-failed {
      0% { margin-left: -3px; }
      50% { margin-left: 3px; }
      100% { margin-left: -3px; }
    }

    @keyframes sword-glow {
      0% { opacity: 0.78; }
      50% { opacity: 1; }
      100% { opacity: 0.78; }
    }

    @keyframes code-mote {
      0% { opacity: 0; }
      35% { opacity: 0.92; }
      100% { opacity: 0; }
    }
  '';

  systemd.user.services.codex-limit-rings = {
    Unit = {
      Description = "Codex limit rings desktop widget";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${codexLimitRingsService}/bin/codex-limit-rings-service";
      ExecStop = "${pkgs.eww}/bin/eww -c %h/.config/eww/codex-limit-rings close codex-limit-rings";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
