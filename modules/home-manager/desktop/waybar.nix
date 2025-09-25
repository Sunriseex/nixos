{ pkgs, ... }:
let
  payments-cli = pkgs.callPackage ../../../scripts/payments-cli/default.nix { };
in
{
  home.file.".local/bin/add-payment" = {
    executable = true;
    text = ''
      #!/bin/sh
      echo "Добавление нового платежа"
      echo "========================"

      read -p "Название: " name
      read -p "Сумма в рублях (например: 349.90): " amount

      echo "Выберите тип:"
      echo "1) По дате"
      echo "2) По количеству дней"
      read -p "Ваш выбор (1 или 2): " choice

      case $choice in
          1)
              read -p "Дата (ГГГГ-ММ-ДД): " date
              days=""
              ;;
          2)
              read -p "Количество дней: " days
              date=""
              ;;
          *)
              echo "Неверный выбор"
              exit 1
              ;;
      esac

      echo "Типы: monthly, yearly, one-time"
      read -p "Тип платежа [monthly]: " type
      type=''${type:-monthly}

      echo "Выберите категорию:"
      echo "1) subscriptions - Подписки"
      echo "2) utilities - Коммунальные услуги"
      echo "3) hosting - Хостинг"
      echo "4) food - Еда"
      echo "5) rent - Аренда"
      echo "6) transport - Транспорт"
      echo "7) entertainment - Развлечения"
      echo "8) healthcare - Здоровье"
      echo "9) other - Другое"
      read -p "Категория [subscriptions]: " category_num

      case $category_num in
          1) category="subscriptions" ;;
          2) category="utilities" ;;
          3) category="hosting" ;;
          4) category="food" ;;
          5) category="rent" ;;
          6) category="transport" ;;
          7) category="entertainment" ;;
          8) category="healthcare" ;;
          9) category="other" ;;
          *) category="subscriptions" ;;
      esac

      echo "Выберите счет оплаты:"
      echo "1) Liabilities:YandexPay"
      echo "2) Liabilities:Tinkoff"
      echo "3) Liabilities:AlfaBank"
      echo "4) Assets:Cash"
      echo "5) Assets:TinkoffCard"
      read -p "Счет [1]: " account_num

      case $account_num in
          1) ledger_account="Liabilities:YandexPay" ;;
          2) ledger_account="Liabilities:Tinkoff" ;;
          3) ledger_account="Liabilities:AlfaBank" ;;
          4) ledger_account="Assets:Cash" ;;
          5) ledger_account="Assets:TinkoffCard" ;;
          *) ledger_account="Liabilities:YandexPay" ;;
      esac

      if [ -n "$days" ]; then
          payments-cli add --name "$name" --amount "$amount" --days "$days" --type "$type" --category "$category" --ledger-account "$ledger_account"
      else
          payments-cli add --name "$name" --amount "$amount" --date "$date" --type "$type" --category "$category" --ledger-account "$ledger_account"
      fi
    '';
  };

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
          "on-click-right" =
            "sh -c '${payments-cli}/bin/payments-cli list | head -n 10 | tr \"\\n\" \"\\r\" | xargs -0 notify-send \"Список платежей\"'";
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
