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

  xdg = {
    enable = true;
    mimeApps = {
      defaultApplications = {
        # Images
        "image/png" = [ "qimgv.desktop" ];
        "image/jpeg" = [ "qimgv.desktop" ];
        "image/gif" = [ "qimgv.desktop" ];
        "image/bmp" = [ "qimgv.desktop" ];
        "image/svg+xml" = [ "qimgv.desktop" ];
        "image/webp" = [ "qimgv.desktop" ];

        # Videos
        "video/mp4" = [ "mpv.desktop" ];
        "video/x-msvideo" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "video/quicktime" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "video/x-ms-wmv" = [ "mpv.desktop" ];
      };
    };
  };

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
