{ config, pkgs, ... }:

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

      read_activity() {
        activity="stale"
        [ -r "$logs_file" ] || return 0

        latest_ts="$(sqlite3 "$logs_file" "SELECT ts FROM logs ORDER BY ts DESC, ts_nanos DESC, id DESC LIMIT 1;" 2>/dev/null || true)"
        [ -n "$latest_ts" ] || return 0

        latest_epoch=""
        case "$latest_ts" in
          *[!0-9]*)
            latest_epoch="$(date -d "$latest_ts" +%s 2>/dev/null || true)"
            ;;
          *)
            if [ "$latest_ts" -gt 1000000000000 ]; then
              latest_epoch="$((latest_ts / 1000))"
            else
              latest_epoch="$latest_ts"
            fi
            ;;
        esac

        [ -n "$latest_epoch" ] || return 0
        now_epoch="$(date +%s)"
        age="$((now_epoch - latest_epoch))"

        if [ "$age" -ge 0 ] && [ "$age" -le 120 ]; then
          activity="active"
        fi
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
      read_activity

      state="idle"
      if [ "$source" = "No data" ]; then
        state="waiting"
      elif [ "$primary" -le 10 ] || [ "$secondary" -le 10 ]; then
        state="failed"
      elif [ "$primary" -le 25 ] || [ "$secondary" -le 25 ]; then
        state="review"
      elif [ "$activity" = "active" ]; then
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

  xdg.configFile."eww/codex-limit-rings/hiyuki.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
      <defs>
        <linearGradient id="hair" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#ffffff"/>
          <stop offset="1" stop-color="#c9d9ee"/>
        </linearGradient>
        <linearGradient id="coat" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#fff9fb"/>
          <stop offset="0.6" stop-color="#f2eef8"/>
          <stop offset="1" stop-color="#d9e7f8"/>
        </linearGradient>
        <filter id="iceGlow" x="-40%" y="-40%" width="180%" height="180%">
          <feGaussianBlur stdDeviation="2.8" result="blur"/>
          <feMerge>
            <feMergeNode in="blur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
      </defs>
      <ellipse cx="64" cy="113" rx="34" ry="7" fill="#1d1d1f" opacity="0.18"/>
      <path d="M99 23 L112 91" stroke="#5cd7ff" stroke-width="7" stroke-linecap="round" filter="url(#iceGlow)"/>
      <path d="M99 23 L112 91" stroke="#147cff" stroke-width="2" stroke-linecap="round"/>
      <path d="M47 74 C37 82 35 103 48 111 H80 C93 103 91 82 81 74 Z" fill="url(#coat)" stroke="#55657d" stroke-width="3"/>
      <circle cx="64" cy="54" r="30" fill="#fafdff" stroke="#55657d" stroke-width="3"/>
      <path d="M35 53 C35 28 52 17 64 19 C41 32 49 47 35 53 Z" fill="url(#hair)" stroke="#7b8da8" stroke-width="2"/>
      <path d="M93 53 C93 28 76 17 64 19 C87 32 79 47 93 53 Z" fill="url(#hair)" stroke="#7b8da8" stroke-width="2"/>
      <path d="M29 63 C20 53 24 41 38 39 C40 51 38 59 29 63 Z" fill="#d92d45" stroke="#7d1024" stroke-width="2"/>
      <path d="M99 63 C108 53 104 41 90 39 C88 51 90 59 99 63 Z" fill="#d92d45" stroke="#7d1024" stroke-width="2"/>
      <circle cx="49" cy="58" r="4" fill="#cf1f3a"/>
      <circle cx="79" cy="58" r="4" fill="#cf1f3a"/>
      <path d="M56 71 Q64 77 72 71" fill="none" stroke="#56657d" stroke-width="3" stroke-linecap="round"/>
      <circle cx="88" cy="35" r="8" fill="#ffffff" stroke="#ffe5ed" stroke-width="4"/>
      <path d="M50 83 L78 83" stroke="#d92d45" stroke-width="3" stroke-linecap="round"/>
      <path d="M42 92 L86 92" stroke="#7dbbff" stroke-width="4" stroke-linecap="round"/>
    </svg>
  '';

  xdg.configFile."eww/codex-limit-rings/eww.yuck".text = ''
    (defpoll primary :interval "30s" "codex-limit-rings-status primary")
    (defpoll secondary :interval "30s" "codex-limit-rings-status secondary")
    (defpoll pet_state :interval "30s" "codex-limit-rings-status state")

    (defwidget hiyuki-pet []
      (overlay :class "pet-stage"
        (image :class "pet-image ''${pet_state}" :path "${config.xdg.configHome}/eww/codex-limit-rings/hiyuki.svg" :image-width 112 :image-height 112)
        (label :class "pet-code code-a ''${pet_state}" :text "</>")
        (label :class "pet-code code-b ''${pet_state}" :text "{}")
        (label :class "pet-code code-c ''${pet_state}" :text "fn")))

    (defwidget token-bar [name value style]
      (box :class "token-row ''${style}" :orientation "v" :spacing 3
        (box :class "token-head" :orientation "h"
          (label :class "token-name" :text name)
          (label :class "token-value" :text "''${value}%"))
        (progress :class "token-progress" :value value :orientation "h")))

    (defwidget codex-limit-rings []
      (box :class "rings-wrap" :orientation "v" :spacing 7
        (hiyuki-pet)
        (token-bar :name "Primary" :value primary :style "primary")
        (token-bar :name "Secondary" :value secondary :style "secondary")))

    (defwindow codex-limit-rings
      :monitor 0
      :geometry (geometry :x "24px" :y "96px" :width "154px" :height "180px" :anchor "top right")
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
      padding: 0;
      background: transparent;
      border: 0;
      box-shadow: none;
      color: #1d1d1f;
    }

    .pet-stage {
      min-width: 154px;
      min-height: 116px;
    }

    .pet-image {
      min-width: 112px;
      min-height: 112px;
      animation: pet-idle 2.6s ease-in-out infinite;
    }

    .pet-image.running {
      animation: pet-running 0.72s steps(2, end) infinite;
    }

    .pet-image.review {
      animation: pet-review 1.1s ease-in-out infinite;
    }

    .pet-image.waiting {
      animation: pet-waiting 1.9s ease-in-out infinite;
    }

    .pet-image.failed {
      animation: pet-failed 0.34s steps(2, end) infinite;
    }

    .pet-code {
      color: #0a84ff;
      font-size: 10px;
      text-shadow: 0 0 8px rgba(10, 132, 255, 0.9);
      opacity: 0;
    }

    .code-a {
      margin: 22px 0 0 18px;
    }

    .code-b {
      margin: 54px 0 0 122px;
    }

    .code-c {
      margin: 78px 0 0 28px;
    }

    .pet-code.running,
    .pet-code.review,
    .pet-code.failed {
      animation: code-mote 1.1s ease-in-out infinite;
    }

    .pet-code.review {
      color: #ff9f0a;
      text-shadow: 0 0 8px rgba(255, 159, 10, 0.9);
    }

    .pet-code.failed {
      color: #ff453a;
      text-shadow: 0 0 8px rgba(255, 69, 58, 0.9);
    }

    .token-row {
      min-width: 154px;
      min-height: 25px;
    }

    .token-head {
      min-width: 154px;
    }

    .token-name {
      color: rgba(245, 245, 247, 0.78);
      font-size: 10px;
    }

    .token-value {
      color: #f5f5f7;
      font-size: 10px;
      margin-left: 8px;
    }

    .token-progress {
      min-width: 154px;
      min-height: 7px;
      border-radius: 999px;
    }

    .token-progress trough {
      min-width: 154px;
      min-height: 7px;
      border-radius: 999px;
      background: rgba(245, 245, 247, 0.22);
    }

    .token-progress progress {
      min-height: 7px;
      border-radius: 999px;
      background: #34c759;
    }

    .secondary .token-progress progress {
      background: #0a84ff;
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
