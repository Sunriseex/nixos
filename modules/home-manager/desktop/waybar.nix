{ ... }:

{
  home.file.".config/waybar/scripts/weather.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      API_KEY=""
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

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 50;
        spacing = 0;

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
          "custom/lock"
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
          all-outputs = true;
          format = "{icon}";
          on-click = "activate";
        };

        "custom/lock" = {
          "format" = "    ";
          "on-click" = "hyprlock";
          "tooltip" = false;
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
          format = " {:%H:%M:%S}";
          tooltip = true;
          tooltip-format = "{:L%A %d/%m/%Y}";
        };

        tray = {
          icon-size = 17;
          spacing = 6;
          protocol = "status-notifier";
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

      /* Waybar */
      #waybar {
        background-color: rgba(0, 0, 0, 0);
        border: none;
        box-shadow: none;
      }

      /* Workspaces */
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

      /* Левые модули */
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

      /* Правые модули - объединенная группа */
      #tray, #pulseaudio, #pulseaudio\\#microphone, #custom-weather, #clock, #custom-lock, #custom-power {
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

      /* Модуль с музыкой */
      #custom-nowplaying {
        background-color: #323844;
        margin: 6px 6px 0 6px;
        padding: 4px 8px;
        border-radius: 10px;
        font-style: italic;
      }

      /* Ховер-эффекты */
      #language:hover,
      #cpu:hover,
      #memory:hover,
      #custom-nowplaying:hover,
      #tray:hover,
      #pulseaudio:hover,
      #pulseaudio\\#microphone:hover,
      #custom-weather:hover,
      #clock:hover,
      #custom-lock:hover,
      #custom-power:hover {
        background-color: rgba(70, 75, 90, 0.9);
      }

      /* Рабочие пространства */
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
        background-color: #151B27;
        color: #ffffff;
      }
    '';
  };
}
