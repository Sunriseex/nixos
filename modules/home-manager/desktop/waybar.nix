{ pkgs, ... }:
let
  payments-cli = pkgs.callPackage ../../../scripts/payments-cli/default.nix { };
in
{
  home.file.".config/waybar/scripts/weather.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      API_KEY="af3ae71b2d4279e59e4f1c9a94057d64"
      CITY="Moscow"
      URL="https://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$API_KEY&units=metric&lang=ru"

      WEATHER_JSON=$(curl -s "$URL")
      TEMP=$(echo "$WEATHER_JSON" | jq '.main.temp' | cut -d. -f1)
      WEATHER_DESC=$(echo "$WEATHER_JSON" | jq -r '.weather[0].description')
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
      DURATION_WORK=1500  # 25 минут
      DURATION_BREAK=300   # 5 минут
      DURATION_LONG_BREAK=900  # 15 минут после 4 циклов

      # Функция для воспроизведения звука
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
        
        # Проверяем доступность звуковых файлов и плееров
        if [ -f "$sound_file" ]; then
          # Пробуем разные плееры
          if command -v paplay >/dev/null 2>&1; then
            paplay "$sound_file" --volume=30000 &  # 30% громкости
          elif command -v aplay >/dev/null 2>&1; then
            aplay "$sound_file" & 2>/dev/null
          elif command -v mpv >/dev/null 2>&1; then
            mpv --no-video --volume=30 "$sound_file" & >/dev/null 2>&1
          elif command -v play >/dev/null 2>&1; then
            play "$sound_file" vol 0.3 & >/dev/null 2>&1
          fi
        fi
      }

      # Функция для отправки уведомления со звуком
      notify_with_sound() {
        local title="$1"
        local message="$2"
        local sound_type="$3"
        
        notify-send "$title" "$message"
        play_sound "$sound_type"
      }

      # Читаем счетчик циклов
      if [ -f "$COUNTER_FILE" ]; then
        CYCLES=$(cat "$COUNTER_FILE")
      else
        CYCLES=0
      fi

      case "$1" in
        "toggle")
          if [ -f "$STATE_FILE" ]; then
            # Если таймер активен, ставим на паузу
            if [ -f "$PAUSE_FILE" ]; then
              # Если уже на паузе, возобновляем
              read paused_mode paused_remaining < "$PAUSE_FILE"
              echo "$paused_mode $(( $(date +%s) + paused_remaining ))" > "$STATE_FILE"
              rm -f "$PAUSE_FILE"
              notify_with_sound "Pomodoro" "Таймер возобновлен" "work_start"
            else
              # Ставим на паузу
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
            # Если таймер не активен, запускаем новый
            if [ -f "$PAUSE_FILE" ]; then
              # Если есть состояние паузы, используем его
              read paused_mode paused_remaining < "$PAUSE_FILE"
              echo "$paused_mode $(( $(date +%s) + paused_remaining ))" > "$STATE_FILE"
              rm -f "$PAUSE_FILE"
            else
              # Запускаем новый таймер (рабочий интервал)
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

      # Отображение состояния
      if [ -f "$STATE_FILE" ]; then
        read mode end_time < "$STATE_FILE"
        current_time=$(date +%s)
        remaining=$(( end_time - current_time ))
        
        # Проверяем, истекло ли время
        if [ "$remaining" -le 0 ]; then
          if [ "$mode" = "work" ]; then
            # Завершился рабочий интервал
            CYCLES=$((CYCLES + 1))
            echo "$CYCLES" > "$COUNTER_FILE"
            
            # Определяем тип перерыва
            if [ $((CYCLES % 4)) -eq 0 ]; then
              # Каждый 4-й цикл - длинный перерыв
              break_duration=$DURATION_LONG_BREAK
              notify_with_sound "Pomodoro" "Рабочий интервал завершен! Время длинного перерыва (15 минут). Цикл: $CYCLES" "long_break_start"
            else
              # Обычный перерыв
              break_duration=$DURATION_BREAK
              notify_with_sound "Pomodoro" "Рабочий интервал завершен! Время перерыва (5 минут). Цикл: $CYCLES" "break_start"
            fi
            
            # Запускаем перерыв
            echo "break $(( current_time + break_duration ))" > "$STATE_FILE"
            mode="break"
            remaining=$break_duration
            
          else
            # Завершился перерыв
            if [ $((CYCLES % 4)) -eq 0 ]; then
              notify_with_sound "Pomodoro" "Длинный перерыв завершен! Возвращайтесь к работе. Цикл: $CYCLES" "work_start"
            else
              notify_with_sound "Pomodoro" "Перерыв завершен! Возвращайтесь к работе. Цикл: $CYCLES" "work_start"
            fi
            
            # Автоматически запускаем следующий рабочий интервал
            echo "work $(( current_time + $DURATION_WORK ))" > "$STATE_FILE"
            mode="work"
            remaining=$DURATION_WORK
          fi
        fi

        # Отображаем оставшееся время
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
        # Таймер на паузе
        read mode remaining < "$PAUSE_FILE"
        minutes=$(( remaining / 60 ))
        seconds=$(( remaining % 60 ))
        
        printf "󰏤 %02d:%02d (%d)\n" $minutes $seconds $CYCLES
        
      else
        # Таймер не активен
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
        output = "HDMI-A-1";

        modules-left = [
          "hyprland/language"
          "cpu"
          "memory"
          "custom/nowplaying"
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
        output = "DVI-D-1";

        modules-left = [ "custom/payments" ];
        modules-center = [
          "custom/pomodoro"
          "hyprland/workspaces"
        ];
        modules-right = [ "clock" ];

        "hyprland/workspaces" = {
          disable-scroll = false;
          all-outputs = false;
          format = "{icon}";
          on-click = "activate";
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
          "exec" = "${payments-cli}/bin/payments-cli";
          "interval" = 60;
          "on-click" = "${payments-cli}/bin/payments-cli paid";
          "on-click-right" = "${payments-cli}/bin/payments-cli list";
          "tooltip" = true;
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

      #tray, #pulseaudio, #pulseaudio\\#microphone, #custom-weather, #clock, #custom-power {
        background-color: #323844;
        margin: 6px 0 0 0;
        padding: 4px 8px;
        border-radius: 0;
      }

      #tray {
        margin-left: 6px;
        border-top-left-radius: 10px;
        border-bottom-left-radius: 10px;
      }

      #custom-power {
        margin-right: 6px;
        border-top-right-radius: 10px;
        border-bottom-right-radius: 10px;
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

      #secondaryBar #custom-pomodoro {
        background-color: #323844;
        margin: 6px 0 0 0;
        padding: 4px 8px;
        border-radius: 0;
      }

      #secondaryBar #custom-payments {
        background-color: #323844;
        margin: 6px 0 0 0;
        padding: 4px 8px;
        border-radius: 0;
      }

      #secondaryBar #clock {
        background-color: #323844;
        margin: 6px 6px 0 0;
        padding: 4px 8px;
        border-radius: 0 10px 10px 0;
      }


      #secondaryBar #workspaces:hover,
      #secondaryBar #custom-pomodoro:hover,
      #secondaryBar #custom-payments:hover,
      #secondaryBar #clock:hover {
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
  home.packages = [ payments-cli ];
}
