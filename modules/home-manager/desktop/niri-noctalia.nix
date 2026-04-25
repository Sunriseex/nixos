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
  '';

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

    window-rule {
        geometry-corner-radius 12
        clip-to-geometry true
    }

    window-rule {
        match app-id=r#"firefox$"# title="^Picture-in-Picture$"
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
    spawn-at-startup "v2rayN"
    spawn-at-startup "Telegram"
    spawn-at-startup "KeePassXC"
    spawn-at-startup "spotify"
    spawn-at-startup "discord"

    binds {
        Mod+Return { spawn "ghostty"; }
        Mod+V { spawn "code" "--wait"; }
        Mod+B { spawn "firefox"; }
        Mod+E { spawn "nemo"; }
        Mod+Space { ${noctalia ''"launcher" "toggle"''}; }
        Mod+S { ${noctalia ''"controlCenter" "toggle"''}; }
        Mod+Comma { ${noctalia ''"settings" "toggle"''}; }
        Mod+P { ${noctalia ''"sessionMenu" "toggle"''}; }
        Mod+Shift+L { ${noctalia ''"lockScreen" "lock"''}; }

        Mod+Q { close-window; }
        Mod+M { quit; }
        Mod+F { fullscreen-window; }
        Mod+Shift+W { toggle-window-floating; }
        Mod+Tab { focus-workspace-down; }
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
