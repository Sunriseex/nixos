{ pkgs, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
  };

  programs.silentSDDM = {
    enable = true;
    # опционально: если модуль поддерживает пресеты/темы, можно выбрать:
    # theme = "rei";
  };
}
