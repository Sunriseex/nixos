{ pkgs, ... }:
let
  sddmWestonIni = pkgs.writeText "sddm-weston.ini" ''
    [output]
    name=HDMI-A-1
    mode=preferred
    position=0,0

    [output]
    name=HDMI-1
    mode=preferred
    position=0,0

    [output]
    name=DVI-D-1
    mode=off

    [output]
    name=DVI-1
    mode=off
  '';
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "weston";
    package = pkgs.kdePackages.sddm;
    settings = {
      Wayland = {
        CompositorCommand = "${pkgs.weston}/bin/weston --shell=kiosk -c ${sddmWestonIni}";
      };
    };
  };

  programs.silentSDDM = {
    enable = true;
    # опционально: если модуль поддерживает пресеты/темы, можно выбрать:
    # theme = "rei";
  };
}
