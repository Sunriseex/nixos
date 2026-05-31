{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  wallpaper = builtins.path {
    path = ../../../wallpapers/dark-bright-mountains.jpg;
    name = "dark-bright-mountains.jpg";
  };

  noctalia = command: ''spawn "noctalia-shell" "ipc" "call" ${command}'';
  noctaliaMacOSTheme = pkgs.writeShellApplication {
    name = "noctalia-macos-theme";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      noctalia-shell
    ];
    text = ''
      set -euo pipefail

      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      noctalia_dir="$config_home/noctalia"
      settings_file="$noctalia_dir/settings.json"
      colors_file="$noctalia_dir/colors.json"
      scheme_file="$noctalia_dir/colorschemes/macOS/macOS.json"

      if [ ! -f "$scheme_file" ]; then
        echo "macOS color scheme is missing: $scheme_file" >&2
        exit 1
      fi

      dark_mode="$(jq -r '.colorSchemes.darkMode // true' "$settings_file" 2>/dev/null || printf true)"
      if [ "$dark_mode" = "true" ]; then
        jq '.dark' "$scheme_file" > "$colors_file.tmp"
      else
        jq '.light' "$scheme_file" > "$colors_file.tmp"
      fi
      mv "$colors_file.tmp" "$colors_file"

      jq '.colorSchemes.predefinedScheme = "macOS" | .colorSchemes.useWallpaperColors = false' \
        "$settings_file" > "$settings_file.tmp"
      mv "$settings_file.tmp" "$settings_file"

      noctalia-shell ipc call colorScheme set macOS >/dev/null 2>&1 || true
      noctalia-shell list 2>/dev/null \
        | sed -n 's/^  Config path: //p' \
        | while IFS= read -r config_path; do
            noctalia-shell -p "$config_path" ipc call colorScheme set macOS >/dev/null 2>&1 || true
          done
    '';
  };
  macOSColorScheme = {
    dark = {
      mPrimary = "#0a84ff";
      mOnPrimary = "#ffffff";
      mSecondary = "#64d2ff";
      mOnSecondary = "#0b0b0f";
      mTertiary = "#bf5af2";
      mOnTertiary = "#ffffff";
      mError = "#ff453a";
      mOnError = "#ffffff";
      mSurface = "#1c1c1e";
      mOnSurface = "#f5f5f7";
      mSurfaceVariant = "#2c2c2e";
      mOnSurfaceVariant = "#aeaeb2";
      mOutline = "#48484a";
      mShadow = "#000000";
      mHover = "#3a3a3c";
      mOnHover = "#f5f5f7";
      terminal = {
        normal = {
          black = "#1c1c1e";
          red = "#ff453a";
          green = "#32d74b";
          yellow = "#ffd60a";
          blue = "#0a84ff";
          magenta = "#bf5af2";
          cyan = "#64d2ff";
          white = "#f5f5f7";
        };
        bright = {
          black = "#636366";
          red = "#ff6961";
          green = "#5ee578";
          yellow = "#ffe55c";
          blue = "#409cff";
          magenta = "#d184ff";
          cyan = "#8fe6ff";
          white = "#ffffff";
        };
        foreground = "#f5f5f7";
        background = "#1c1c1e";
        selectionFg = "#ffffff";
        selectionBg = "#3a3a3c";
        cursorText = "#1c1c1e";
        cursor = "#0a84ff";
      };
    };
    light = {
      mPrimary = "#007aff";
      mOnPrimary = "#ffffff";
      mSecondary = "#5ac8fa";
      mOnSecondary = "#1d1d1f";
      mTertiary = "#af52de";
      mOnTertiary = "#ffffff";
      mError = "#ff3b30";
      mOnError = "#ffffff";
      mSurface = "#f5f5f7";
      mOnSurface = "#1d1d1f";
      mSurfaceVariant = "#ffffff";
      mOnSurfaceVariant = "#6e6e73";
      mOutline = "#d2d2d7";
      mShadow = "#d1d1d6";
      mHover = "#e8e8ed";
      mOnHover = "#1d1d1f";
      terminal = {
        normal = {
          black = "#f5f5f7";
          red = "#ff3b30";
          green = "#28cd41";
          yellow = "#ffcc00";
          blue = "#007aff";
          magenta = "#af52de";
          cyan = "#5ac8fa";
          white = "#1d1d1f";
        };
        bright = {
          black = "#8e8e93";
          red = "#ff453a";
          green = "#32d74b";
          yellow = "#ffd60a";
          blue = "#0a84ff";
          magenta = "#bf5af2";
          cyan = "#64d2ff";
          white = "#000000";
        };
        foreground = "#1d1d1f";
        background = "#f5f5f7";
        selectionFg = "#1d1d1f";
        selectionBg = "#d2d2d7";
        cursorText = "#ffffff";
        cursor = "#007aff";
      };
    };
  };
  macOSColorSchemeFile = pkgs.writeText "macOS-noctalia-colorscheme.json" (
    builtins.toJSON macOSColorScheme
  );
  initialNoctaliaSettings = {
    general = {
      radiusRatio = 0.2;
    };
    location = {
      name = "Moscow, Russia";
    };
    wallpaper = {
      enableOverviewWallpaper = false;
    };
  };
  initialNoctaliaWallpapers = {
    defaultWallpaper = "${wallpaper}";
    wallpapers = {
      "HDMI-A-1" = "${wallpaper}";
      "DVI-D-1" = "${wallpaper}";
    };
  };
  initialNoctaliaSettingsFile = pkgs.writeText "noctalia-initial-settings.json" (
    builtins.toJSON initialNoctaliaSettings
  );
  initialNoctaliaWallpapersFile = pkgs.writeText "noctalia-initial-wallpapers.json" (
    builtins.toJSON initialNoctaliaWallpapers
  );
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell.enable = true;

  home.packages = with pkgs; [
    brightnessctl
    noctaliaMacOSTheme
    playerctl
    wl-clipboard
    xwayland-satellite
  ];

  home.activation.noctaliaWritableState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seed_json_file() {
      file="$1"
      seed="$2"

      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$file")"

      if [ -L "$file" ]; then
        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        if [ -e "$file" ]; then
          ${pkgs.coreutils}/bin/cp --remove-destination "$(${pkgs.coreutils}/bin/readlink -f "$file")" "$tmp" 2>/dev/null \
            || ${pkgs.coreutils}/bin/cp --remove-destination "$seed" "$tmp"
        else
          ${pkgs.coreutils}/bin/cp --remove-destination "$seed" "$tmp"
        fi
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$file"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 "$tmp" "$file"
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      elif [ ! -e "$file" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm0644 "$seed" "$file"
      fi
    }

    seed_json_file "$HOME/.config/noctalia/settings.json" "${initialNoctaliaSettingsFile}"
    seed_json_file "$HOME/.cache/noctalia/wallpapers.json" "${initialNoctaliaWallpapersFile}"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm0644 "${macOSColorSchemeFile}" "$HOME/.config/noctalia/colorschemes/macOS/macOS.json"
  '';

  xdg.configFile."autostart/v2rayN.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=v2rayN
      Exec=v2rayN
      Hidden=true
    '';
  };

  xdg.configFile."autostart/org.keepassxc.KeePassXC.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=KeePassXC
      Exec=KeePassXC
      Hidden=true
    '';
  };

  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us,ru"
                options "grp:alt_shift_toggle"
            }

            numlock
        }

        touchpad {
            tap
            natural-scroll
        }

        focus-follows-mouse
    }

    output "HDMI-A-1" {
        mode "1920x1080"
        scale 1
        position x=0 y=0
        focus-at-startup
    }

    output "HDMI-1" {
        mode "1920x1080"
        scale 1
        position x=0 y=0
        focus-at-startup
    }

    output "DVI-D-1" {
        mode "1920x1080"
        scale 1
        position x=-1920 y=0
    }

    output "DVI-1" {
        mode "1920x1080"
        scale 1
        position x=-1920 y=0
    }

    layout {
        gaps 8
        center-focused-column "never"
        background-color "transparent"

        default-column-width {
            proportion 1.0
        }

        focus-ring {
            width 2
            active-color "#9ca2ae"
            inactive-color "#0e1420"
        }

        border {
            off
        }

        shadow {
            on
            softness 20
            spread 4
            offset x=0 y=4
            color "#0008"
        }
    }

    prefer-no-csd

    cursor {
        xcursor-theme "WhiteSur-cursors"
        xcursor-size 20
        hide-when-typing
        hide-after-inactive-ms 5000
    }

    window-rule {
        geometry-corner-radius 12
        clip-to-geometry true
    }

    window-rule {
        match app-id=r#"helium$"# title="^Picture-in-Picture$"
        open-floating true
    }

    window-rule {
        match app-id=r#"librewolf$"# title="^Picture-in-Picture$"
        open-floating true
    }

    layer-rule {
        match namespace="^noctalia-wallpaper*"
        place-within-backdrop true
    }

    layer-rule {
        match namespace="^noctalia-overview*"
        place-within-backdrop true
    }

    overview {
        workspace-shadow {
            off
        }
    }

    debug {
        honor-xdg-activation-with-invalid-serial
    }

    hotkey-overlay {
        skip-at-startup
    }

    spawn-at-startup "noctalia-shell"
    spawn-at-startup "sh" "-c" "${pkgs.procps}/bin/pgrep -x v2rayN >/dev/null || exec v2rayN"
    spawn-at-startup "Telegram"
    spawn-at-startup "KeePassXC"
    spawn-at-startup "spotify"
    spawn-at-startup "sh" "-c" "${pkgs.coreutils}/bin/sleep 20; exec discord"

    binds {
        Mod+Return { spawn "ghostty"; }
        Mod+V { spawn "code" "--wait"; }
        Mod+B { spawn "helium"; }
        Mod+E { spawn "nemo"; }
        Mod+Space { spawn "vicinae" "toggle"; }
        Mod+S { ${noctalia ''"controlCenter" "toggle"''}; }
        Mod+Comma { ${noctalia ''"settings" "toggle"''}; }
        Mod+P { ${noctalia ''"sessionMenu" "toggle"''}; }
        Mod+Shift+L { ${noctalia ''"lockScreen" "lock"''}; }
        Mod+Shift+C { spawn "cursor-locator"; }
        Mod+Shift+T { spawn "noctalia-macos-theme"; }


        Mod+Q { close-window; }
        Mod+M { quit; }
        Mod+F { fullscreen-window; }
        Mod+Shift+W { toggle-window-floating; }
        Mod+Tab { toggle-overview; }
        Alt+Tab { toggle-overview; }
        Mod+O { toggle-overview; }

        Mod+H { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+L { focus-column-right; }
        Mod+Left { move-column-left; }
        Mod+Right { move-column-right; }
        Mod+Up { move-window-up; }
        Mod+Down { move-window-down; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        Mod+0 { focus-workspace 10; }

        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }
        Mod+Shift+0 { move-column-to-workspace 10; }

        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

        Print { screenshot; }
        Shift+Print { screenshot-window; }

        XF86AudioRaiseVolume allow-when-locked=true { ${noctalia ''"volume" "increase"''}; }
        XF86AudioLowerVolume allow-when-locked=true { ${noctalia ''"volume" "decrease"''}; }
        XF86AudioMute allow-when-locked=true { ${noctalia ''"volume" "muteOutput"''}; }
        Shift+XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+"; }
        Shift+XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-"; }
        Shift+XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
        XF86MonBrightnessUp allow-when-locked=true { ${noctalia ''"brightness" "increase"''}; }
        XF86MonBrightnessDown allow-when-locked=true { ${noctalia ''"brightness" "decrease"''}; }

        XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
        XF86AudioPause allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
    }
  '';
}
