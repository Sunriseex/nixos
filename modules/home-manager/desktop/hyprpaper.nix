{ ... }:

let
  wp = builtins.path {
    path = ../../../wallpapers/dark-bright-mountains.jpg;
    name = "dark-bright-mountains.jpg";
  };
in
{
  services.hyprpaper.enable = true;

  # НЕ задаём services.hyprpaper.settings, чтобы HM не писал старый синтаксис
  services.hyprpaper.settings = { };

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    wallpaper {
      monitor = HDMI-A-1
      path = ${wp}
      fit_mode = cover
    }
    wallpaper {
      monitor = DVI-D-1
      path = ${wp}
      fit_mode = cover
    }
  '';
}
