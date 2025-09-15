{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/home-manager
    inputs.agenix.homeManagerModules.default
  ];

  home = {
    username = "snrx";
    homeDirectory = "/home/snrx";
    stateVersion = "25.05"; # Do not change
  };

  home.packages = with pkgs; [
    dconf
    gopls
    delve
    golangci-lint
    zoxide
    atuin
  ];

  home.sessionVariables = {
    TERMINAL = "ghostty";
    EDITOR = "code --wait";
    VISUAL = "code --wait";
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
