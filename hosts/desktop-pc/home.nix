{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home-manager
  ];

  home = { 
    username = "snrx";
    homeDirectory = "/home/snrx";
    stateVersion = "25.11"; # Do not change
  };

  home.packages = with pkgs; [
    dconf
  ];

  home.sessionVariables = {
    TERMINAL = "kitty";
    EDITOR = "nvim";
    VISUAL = "nvim";
    HYPRSHOT_DIR = /home/snrx/Screenshots;
  };

  home.sessionPath = [
    "/Nixos/scripts"
    "/Nixos/scripts/nixos"
    "/Nixos/scripts/system"
    "/Nixos/scripts/hypr"
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
