{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ../../modules/home-manager
    inputs.agenix.homeManagerModules.default
    inputs.helium-browser.homeModules.default
  ];

  home = {
    username = "snrx";
    homeDirectory = "/home/snrx";
    stateVersion = "25.05"; # Do not change
  };

  home.packages = with pkgs; [
    dconf
    pkgs.remmina
    vicinae
  ];
  # gtk.gtk4.theme = config.gtk.theme;
  programs.neovim.withRuby = true;
  programs.neovim.withPython3 = true;

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

  systemd.user.services.vicinae = {
    Unit = {
      Description = "Vicinae Launcher Daemon";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.vicinae}/bin/vicinae server --replace";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
  home.sessionVariables = {
    TERMINAL = "ghostty";
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/scripts/nixos"
    "$HOME/scripts/system"
  ];
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
