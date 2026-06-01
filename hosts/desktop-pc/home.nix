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
  home.sessionVariables =
    let
      proxy = "socks5h://127.0.0.1:10808";
      noProxy = "127.0.0.1,localhost,::1,home.arpa,.home.arpa,192.168.56.0/24,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
    in
    {
      TERMINAL = "ghostty";
      EDITOR = "nvim";
      VISUAL = "nvim";
      http_proxy = proxy;
      https_proxy = proxy;
      ftp_proxy = proxy;
      rsync_proxy = proxy;
      all_proxy = proxy;
      no_proxy = noProxy;
      HTTP_PROXY = proxy;
      HTTPS_PROXY = proxy;
      FTP_PROXY = proxy;
      RSYNC_PROXY = proxy;
      ALL_PROXY = proxy;
      NO_PROXY = noProxy;
    };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/scripts/nixos"
    "$HOME/scripts/system"
  ];
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
