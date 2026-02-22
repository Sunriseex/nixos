{ config, pkgs, ... }:
let
  finance-manager = pkgs.callPackage ../../../scripts/finance-manager/default.nix { };
  wavePlateIconPath = "${config.home.homeDirectory}/icons/wave-plate.png";
  primaryOutputs = [
    "HDMI-A-1"
    "HDMI-1"
  ];
  secondaryOutputs = [
    "DVI-D-1"
    "DVI-1"
  ];
in
{
  home.file.".config/waybar/scripts/wave-plates.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # wave-plates.sh — fixed-start + persistent base + sync command
      STATE_FILE="/tmp/wave_plates_state.json"
      SYNC_LOCK_FILE="/tmp/wave_plates_sync.lock"

      MAX_LIMIT=240
      REGEN_NORMAL=360       # 6 minutes per plate

      # Defaults (fallback only; actual base/time are read from STATE_FILE)
      DEFAULT_BASE_PLATES=0
      DEFAULT_START_UTC=$(date -d '2025-10-10 21:50:20 UTC' +%s)  # edit if needed

      # debug: set DEBUG=1 to log to /tmp/wave-plates.debug (doesn't affect waybar output)
      LOGFILE="/tmp/wave-plates.debug"
      log() { [[ -n "$DEBUG" ]] && printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOGFILE"; }

      init_state() {
          if [[ ! -f "$STATE_FILE" ]] || ! jq empty "$STATE_FILE" >/dev/null 2>&1; then
              cat > "$STATE_FILE" <<EOF
      {
        "base_plates": $DEFAULT_BASE_PLATES,
        "base_time": $DEFAULT_START_UTC,
        "spent_transactions": []
      }
      EOF
          fi
      }

      # read numeric field with fallback
      read_state_field() {
          local field=$1 fallback=$2
          jq -r --arg fld "$field" --argjson fb "$fallback" 'if has($fld) then .[$fld] else $fb end' "$STATE_FILE"
      }

      # calculate plates
      calculate_plates() {
          local state base_plates base_time current_time elapsed regen_plates spent_sum total_plates

          state=$(cat "$STATE_FILE")
          base_plates=$(echo "$state" | jq -r '.base_plates // '"$DEFAULT_BASE_PLATES")
          base_time=$(echo "$state" | jq -r '.base_time // '"$DEFAULT_START_UTC")
          current_time=$(date +%s)
          elapsed=$(( current_time - base_time ))

          if (( elapsed < 0 )); then
              echo "$base_plates"
              return
          fi

          regen_plates=$(( elapsed / REGEN_NORMAL ))
          # cap so base + regen never exceeds MAX_LIMIT
          if (( base_plates + regen_plates > MAX_LIMIT )); then
              regen_plates=$(( MAX_LIMIT - base_plates ))
              (( regen_plates < 0 )) && regen_plates=0
          fi

          # Sum spends where tx_time >= base_time
          # handle both seconds and milliseconds timestamps robustly
          spent_sum=$(echo "$state" | jq -r --argjson base_time "$base_time" '
            [ .spent_transactions[]? |
              ( (if (.time > 1000000000000) then (.time/1000|floor) else .time end) ) as $t |
              select($t >= $base_time) | .amount ] | add // 0')

          total_plates=$(( base_plates + regen_plates - spent_sum ))
          (( total_plates < 0 )) && total_plates=0
          (( total_plates > MAX_LIMIT )) && total_plates=$MAX_LIMIT

          log "calc: now=$current_time base_time=$base_time base=$base_plates regen=$regen_plates spent=$spent_sum total=$total_plates"
          echo "$total_plates"
      }

      # append spend
      use_plates() {
          local amount=$1 current_time new_tx updated_state tmp
          current_time=$(date +%s)
          new_tx=$(jq -n --argjson time "$current_time" --argjson amount "$amount" '{time: $time, amount: $amount}')
          tmp=$(mktemp)
          jq --argjson tx "$new_tx" '.spent_transactions += [$tx]' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
          log "spend: amount=$amount time=$current_time"
          calculate_plates
      }

      # perform sync: set base_plates to given value (or to current calculated plates if none)
      # and set base_time to now. This ignores older spends by selecting tx.time >= base_time afterwards.
      perform_sync() {
          local set_to now tmp desired
          now=$(date +%s)
          if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
              desired=$1
          else
              desired=$(calculate_plates)
          fi
          tmp=$(mktemp)
          # update base_plates and base_time atomically
          jq --argjson bp "$desired" --argjson bt "$now" '.base_plates = $bp | .base_time = $bt' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
          log "sync: set base_plates=$desired base_time=$now"
          echo "$desired"
      }

      sync_operation() {
          local op=$1 arg=$2
          (
              flock -x 200
              case "$op" in
                  use60) use_plates 60 ;;
                  use40) use_plates 40 ;;
                  calculate) calculate_plates ;;
                  sync) perform_sync "$arg" ;;
                  *) calculate_plates ;;
              esac
          ) 200>"$SYNC_LOCK_FILE"
      }

      # main
      init_state

      case "$1" in
          use60) plates=$(sync_operation use60) ;;
          use40) plates=$(sync_operation use40) ;;
          sync)  plates=$(sync_operation sync "$2") ;;   # usage: sync [NUMBER]
          *)     plates=$(sync_operation calculate) ;;
      esac

      # display
      if (( plates <= 180 )); then
          class="green"
      elif (( plates <= 240 )); then
          class="red"
      else
          class="purple"
      fi

      echo "{\"text\": \"$plates/$MAX_LIMIT\", \"class\": \"$class\"}"
    '';
  };

  home.file.".config/waybar/scripts/weather.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      ENV_FILE="$HOME/.config/waybar/weather.env"
      [ -f "$ENV_FILE" ] && . "$ENV_FILE"

      API_KEY="''${OPENWEATHER_API_KEY:-}"
      CITY="''${OPENWEATHER_CITY:-Moscow}"

      if [ -z "$API_KEY" ]; then
        echo "🌡️ --°C"
        exit 0
      fi

      URL="https://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$API_KEY&units=metric&lang=ru"

      WEATHER_JSON=$(curl -s "$URL")
      if ! echo "$WEATHER_JSON" | jq -e '.main.temp and .weather[0].icon' >/dev/null 2>&1; then
        echo "🌡️ --°C"
        exit 0
      fi

      TEMP=$(echo "$WEATHER_JSON" | jq '.main.temp' | cut -d. -f1)
      ICON_CODE=$(echo "$WEATHER_JSON" | jq -r '.weather[0].icon')

      get_icon() {
          case $1 in
              "01d") echo "☀️";;
              "01n") echo "🌙";;
              "02d") echo "⛅";;
              "02n") echo "⛅";;
              "03d"|"03n") echo "☁️";;
              "04d"|"04n") echo "☁️";;
              "09d"|"09n") echo "🌧️";;
              "10d"|"10n") echo "🌦️";;
              "11d"|"11n") echo "⛈️";;
              "13d"|"13n") echo "❄️";;
              "50d"|"50n") echo "🌫️";;
              *) echo "🌡️";;
          esac
      }

      ICON=$(get_icon "$ICON_CODE")
      echo "$ICON $TEMP°C"
    '';
  };

  home.file.".config/waybar/scripts/pomodoro.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      STATE_FILE="/tmp/pomodoro_state"
      PAUSE_FILE="/tmp/pomodoro_pause"
      COUNTER_FILE="/tmp/pomodoro_counter"
      DURATION_WORK=1500
      DURATION_BREAK=300
      DURATION_LONG_BREAK=900

      play_sound() {
        local sound_type=$1
        local sound_file=""
        
        case "$sound_type" in
          "work_start")
            sound_file="/usr/share/sounds/freedesktop/stereo/bell.oga"
            ;;
          "break_start")
            sound_file="/usr/share/sounds/freedesktop/stereo/window-attention.oga"
            ;;
          "long_break_start")
            sound_file="/usr/share/sounds/freedesktop/stereo/complete.oga"
            ;;
          *)
            sound_file="/usr/share/sounds/freedesktop/stereo/message.oga"
            ;;
        esac
        
        if [ -f "$sound_file" ]; then
          if command -v paplay >/dev/null 2>&1; then
            paplay "$sound_file" --volume=30000 &
          elif command -v aplay >/dev/null 2>&1; then
            aplay "$sound_file" & 2>/dev/null
          elif command -v mpv >/dev/null 2>&1; then
            mpv --no-video --volume=30 "$sound_file" & >/dev/null 2>&1
          elif command -v play >/dev/null 2>&1; then
            play "$sound_file" vol 0.3 & >/dev/null 2>&1
          fi
        fi
      }

      notify_with_sound() {
        local title="$1"
        local message="$2"
        local sound_type="$3"
        
        notify-send "$title" "$message"
        play_sound "$sound_type"
      }

      if [ -f "$COUNTER_FILE" ]; then
        CYCLES=$(cat "$COUNTER_FILE")
      else
        CYCLES=0
      fi

      case "$1" in
        "toggle")
          if [ -f "$STATE_FILE" ]; then
            if [ -f "$PAUSE_FILE" ]; then
              read paused_mode paused_remaining < "$PAUSE_FILE"
              echo "$paused_mode $(( $(date +%s) + paused_remaining ))" > "$STATE_FILE"
              rm -f "$PAUSE_FILE"
              notify_with_sound "Pomodoro" "Таймер возобновлен" "work_start"
            else
              read mode end_time < "$STATE_FILE"
              remaining=$(( end_time - $(date +%s) ))
              if [ "$remaining" -gt 0 ]; then
                echo "$mode $remaining" > "$PAUSE_FILE"
                rm -f "$STATE_FILE"
                notify_with_sound "Pomodoro" "Таймер на паузе" "break_start"
              else
                rm -f "$STATE_FILE"
              fi
            fi
          else
            if [ -f "$PAUSE_FILE" ]; then
              read paused_mode paused_remaining < "$PAUSE_FILE"
              echo "$paused_mode $(( $(date +%s) + paused_remaining ))" > "$STATE_FILE"
              rm -f "$PAUSE_FILE"
            else
              echo "work $(( $(date +%s) + $DURATION_WORK ))" > "$STATE_FILE"
              notify_with_sound "Pomodoro" "Рабочий интервал начался (25 минут)" "work_start"
            fi
          fi
          ;;
        "reset")
          rm -f "$STATE_FILE" "$PAUSE_FILE"
          echo "0" > "$COUNTER_FILE"
          notify-send "Pomodoro" "Таймер сброшен"
          ;;
      esac

      if [ -f "$STATE_FILE" ]; then
        read mode end_time < "$STATE_FILE"
        current_time=$(date +%s)
        remaining=$(( end_time - current_time ))
        
        if [ "$remaining" -le 0 ]; then
          if [ "$mode" = "work" ]; then
            CYCLES=$((CYCLES + 1))
            echo "$CYCLES" > "$COUNTER_FILE"
            
            if [ $((CYCLES % 4)) -eq 0 ]; then
              break_duration=$DURATION_LONG_BREAK
              notify_with_sound "Pomodoro" "Рабочий интервал завершен! Время длинного перерыва (15 минут). Цикл: $CYCLES" "long_break_start"
            else
              break_duration=$DURATION_BREAK
              notify_with_sound "Pomodoro" "Рабочий интервал завершен! Время перерыва (5 минут). Цикл: $CYCLES" "break_start"
            fi
            
            echo "break $(( current_time + break_duration ))" > "$STATE_FILE"
            mode="break"
            remaining=$break_duration
            
          else
            if [ $((CYCLES % 4)) -eq 0 ]; then
              notify_with_sound "Pomodoro" "Длинный перерыв завершен! Возвращайтесь к работе. Цикл: $CYCLES" "work_start"
            else
              notify_with_sound "Pomodoro" "Перерыв завершен! Возвращайтесь к работе. Цикл: $CYCLES" "work_start"
            fi
            
            echo "work $(( current_time + $DURATION_WORK ))" > "$STATE_FILE"
            mode="work"
            remaining=$DURATION_WORK
          fi
        fi

        minutes=$(( remaining / 60 ))
        seconds=$(( remaining % 60 ))
        
        if [ "$mode" = "work" ]; then
          printf "󰔛 %02d:%02d (%d)\n" $minutes $seconds $CYCLES
        else
          if [ $((CYCLES % 4)) -eq 0 ]; then
            printf "󰃟 %02d:%02d (%d)\n" $minutes $seconds $CYCLES
          else
            printf "󰥔 %02d:%02d (%d)\n" $minutes $seconds $CYCLES
          fi
        fi
        
      elif [ -f "$PAUSE_FILE" ]; then
        read mode remaining < "$PAUSE_FILE"
        minutes=$(( remaining / 60 ))
        seconds=$(( remaining % 60 ))
        
        printf "󰏤 %02d:%02d (%d)\n" $minutes $seconds $CYCLES
        
      else
        printf "󰔛 --:-- (%d)\n" $CYCLES
      fi
    '';
  };

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 50;
        spacing = 0;
        output = primaryOutputs;

        modules-left = [
          "hyprland/language"
          "cpu"
          "memory"
        ];
        modules-center = [ "hyprland/workspaces" ];
        modules-right = [
          "tray"
          "pulseaudio"
          "pulseaudio#microphone"
          "custom/weather"
          "clock"
          "custom/power"
        ];

        "custom/weather" = {
          "format" = "{}";
          "exec" = "~/.config/waybar/scripts/weather.sh";
          "interval" = 600;
          "tooltip" = false;
          "on-click" = "xdg-open https://yandex.ru/pogoda/moscow";
        };

        "hyprland/language" = {
          "format" = "⌨️ {}";
          "format-en" = "EN";
          "format-ru" = "RU";
          "tooltip" = false;
          "on-click" =
            "sh -c '\${TERMINAL:-ghostty} sh -c \"fastfetch; echo; read -p \\\"Press enter to exit...\\\"\"'";
        };

        "hyprland/workspaces" = {
          disable-scroll = false;
          all-outputs = false;
          format = "{icon}";
          on-click = "activate";
        };

        "custom/power" = {
          format = "    ";
          on-click = "wlogout -b 5 -r 1";
          tooltip = false;
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰖁 0%";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
              ""
            ];
          };
          on-click-right = "pavucontrol";
          on-click = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
          tooltip = false;
        };

        "pulseaudio#microphone" = {
          format = "{format_source}";
          format-source = " {volume}%";
          format-source-muted = " Muted";
          on-click = "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          on-click-right = "pavucontrol";
          tooltip = false;
        };

        memory = {
          format = " {used:0.1f}G/{total:0.1f}G";
          tooltip = true;
          tooltip-format = "Used RAM: {used:0.2f}G/{total:0.2f}G";
        };

        cpu = {
          format = " {usage}%";
          tooltip = true;
        };

        clock = {
          interval = 1;
          timezone = "Europe/Moscow";
          format = " {:%I:%M %p}";
          tooltip = true;
          tooltip-format = "{:L%A %d/%m/%Y}";
        };

        tray = {
          icon-size = 17;
          spacing = 6;
          protocol = "status-notifier";
        };
      };

      secondaryBar = {
        layer = "top";
        position = "top";
        height = 50;
        spacing = 0;
        output = secondaryOutputs;

        modules-left = [
          "custom/payments"
          "custom/nowplaying"
        ];
        modules-center = [
          "custom/pomodoro"
          "hyprland/workspaces"
        ];
        modules-right = [
          "custom/wave-plates"
          "clock"
        ];

        "custom/nowplaying" = {
          "format" = "{}";
          "exec" = ''
            #!/bin/sh
            status=$(playerctl status 2>/dev/null)

            if [ "$status" = "Playing" ]; then
              current_artist=$(playerctl metadata artist)
              current_title=$(playerctl metadata title)
              echo "▶ $current_artist - $current_title"
            elif [ "$status" = "Paused" ]; then
              echo "⏸ Paused"
            else
             echo "⏹ No music"
            fi
          '';
          "on-click" = "playerctl play-pause";
          "on-scroll-up" = "playerctl next";
          "on-scroll-down" = "playerctl previous";
          "interval" = 1;
          "tooltip" = false;
          "max-length" = 30;
          "escape" = true;
        };

        "hyprland/workspaces" = {
          disable-scroll = false;
          all-outputs = false;
          format = "{icon}";
          on-click = "activate";
        };

        "custom/wave-plates" = {
          "format" = "{}";
          "exec" = "~/.local/bin/wave-plates-widget";
          "interval" = 30;
          "on-click" = "~/.local/bin/wave-plates-widget use60";
          "on-click-right" = "~/.local/bin/wave-plates-widget use40";
          "tooltip" = false;
          "escape" = false;
          "return-type" = "json";
        };

        "custom/pomodoro" = {
          "format" = "{}";
          "exec" = "~/.config/waybar/scripts/pomodoro.sh";
          "interval" = 1;
          "on-click" = "~/.config/waybar/scripts/pomodoro.sh toggle";
          "on-click-right" = "~/.config/waybar/scripts/pomodoro.sh reset";
          "tooltip" = false;
        };

        "custom/payments" = {
          "format" = "{}";
          "exec" = "${finance-manager}/bin/payments-manager";
          "interval" = 60;
          "on-click" = "${finance-manager}/bin/payments-manager paid";
          "on-click-right" =
            "sh -c '${finance-manager}/bin/payments-manager list | head -n 30 | tr \"\\n\" \"\\r\" | xargs -0 notify-send \"Список платежей\"'";
          "tooltip" = false;
        };

        clock = {
          interval = 1;
          timezone = "Europe/Moscow";
          format = " {:%I:%M %p}";
          tooltip = true;
          tooltip-format = "{:L%A %d/%m/%Y}";
        };
      };
    };
    style = ''
      * {
        font-family: "CaskaydiaCove Nerd Font", "Font Awesome 6 Free", "Font Awesome 6 Free Solid";
        font-weight: bold;
        font-size: 16px;
        color: #dcdfe1;
      }

      #waybar {
        background-color: rgba(0, 0, 0, 0);
        border: none;
        box-shadow: none;
      }

      #workspaces {
        background-color: #323844;
        padding: 4px 6px; 
        margin: 6px 6px 0 6px;
        border-radius: 10px;
        border-width: 0px;
      }

      #language {
        background-color: #323844;
        margin-top: 6px;
        margin-left: 6px;
        margin-right: 6px;
        padding: 4px 8px;
        border-radius: 10px;
        color: #dcdfe1;
      }

      #language:hover {
        background-color: rgba(70, 75, 90, 0.9);
        color: #ffffff;
      }

      #cpu, #memory {
        background-color: #323844;
        margin: 6px 0 0 0;
        padding: 4px 8px;
        border-radius: 0;
      }

      #cpu {
        margin-left: 6px;
        border-top-left-radius: 10px;
        border-bottom-left-radius: 10px;
      }

      #memory {
        border-top-right-radius: 10px;
        border-bottom-right-radius: 10px;
      }

      #tray, #pulseaudio, #pulseaudio\\#microphone, #custom-weather, #custom-power {
        background-color: #323844;
        margin: 6px 0 0 0;
        padding: 4px 8px;
        border-radius: 0;
      }

      #custom-weather {
      border-top-right-radius: 10px;
      border-bottom-right-radius: 10px;
      }

      #tray {
        margin-left: 6px;
        border-top-left-radius: 10px;
        border-bottom-left-radius: 10px;
      }

      #custom-power {
        margin-right: 6px;
        border-radius: 10px;
      }

      #custom-nowplaying {
        background-color: #323844;
        margin: 6px 6px 0 6px;
        padding: 4px 8px;
        border-radius: 10px;
        font-style: italic;
      }

      #language:hover,
      #cpu:hover,
      #memory:hover,
      #custom-nowplaying:hover,
      #tray:hover,
      #pulseaudio:hover,
      #pulseaudio\\#microphone:hover,
      #custom-weather:hover,
      #clock:hover,
      #custom-power:hover {
        background-color: rgba(255, 107, 53, 0.15);
        color: #FFFFFF;
        border-top: none;
        border-left: none;
        border-right: none;
        border-bottom: 1px solid #FF6B35;
        box-shadow: 0 0 5px rgba(255, 107, 53, 0.5);
        transition: border-bottom 0.6s ease-in-out;
      }

      #workspaces button {
        background: transparent;
        border: none;
        color: #888888;
        padding: 2px 8px;
        margin: 0 2px;
        font-weight: bold;
        border-radius: 10px;
      }

      #workspaces button:hover {
        background-color: rgba(97, 175, 239, 0.2);
      }

      #workspaces button.active {
        background-color: #FF6B35;
        color: #FFFFFF;
        border: none;  
        box-shadow: 0 0 10px rgba(255, 107, 53, 0.7);
      }

      #waybar.secondaryBar {
        background-color: rgba(0, 0, 0, 0);
        border: none;
        box-shadow: none;
      }

      #secondaryBar #workspaces {
        background-color: #323844;
        padding: 4px 6px; 
        margin: 6px 0 0 6px;
        border-radius: 10px 0 0 10px;
        border-width: 0px;
      }

      #custom-pomodoro {
        background-color: #323844;
        margin: 6px 0 0 0;
        padding: 4px 8px;
        border-radius: 10px;
      }

      #custom-payments {
        background-color: #323844;
        margin: 6px 0 0 0;
        padding: 4px 8px;
        border-radius: 10px;
      }

      #clock {
        background-color: #323844;
        margin: 6px 6px 0 0;
        padding: 4px 8px;
        border-radius: 10px;
      }

      #custom-wave-plates {
      background-image: url("${wavePlateIconPath}");
      background-repeat: no-repeat;
      background-size: 24px 24px;
      background-position: left center;
      padding-left: 20px;
      padding-right:6px;
      background-color: #323844;
      margin: 6px 0 0 6px;
      border-radius: 10px;
      min-width: 60px;
      }

      #custom-wave-plates.green {
        color: #8bc34a; 
      }

      #custom-wave-plates.red {
        color: #f44336; 
      }

      #custom-wave-plates.purple {
        color: #9c27b0; 
      }


      #workspaces:hover,
      #custom-pomodoro:hover,
      #custom-payments:hover,
      #clock:hover {
        background-color: rgba(255, 107, 53, 0.15);
        color: #FFFFFF;
        border-top: none;
        border-left: none;
        border-right: none;
        border-bottom: 1px solid #FF6B35;
        box-shadow: 0 0 5px rgba(255, 107, 53, 0.5);
        transition: border-bottom 0.6s ease-in-out;
      }

      #custom-wave-plates:hover {
        background-color: rgba(255, 107, 53, 0.15);
        color: #FFFFFF;
        border-top: none;
        border-left: none;
        border-right: none;
        border-bottom: 1px solid #FF6B35;
        box-shadow: 0 0 5px rgba(255, 107, 53, 0.5);
        transition: border-bottom 0.6s ease-in-out;
      }


      #secondaryBar #workspaces button {
        background: transparent;
        border: none;
        color: #888888;
        padding: 2px 8px;
        margin: 0 2px;
        font-weight: bold;
        border-radius: 10px;
      }

      #secondaryBar #workspaces button:hover {
        background-color: rgba(97, 175, 239, 0.2);
      }

      #secondaryBar #workspaces button.active {
        background-color: #FF6B35;
        color: #FFFFFF;
        border: none;
        box-shadow: 0 0 5px rgba(255, 107, 53, 0.5);
      }
    '';
  };
  home.packages = [ finance-manager ];
}
