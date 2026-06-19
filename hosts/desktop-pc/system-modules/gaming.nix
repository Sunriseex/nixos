{ pkgs, ... }:

let
  unsetProxyEnv = ''
    --unset http_proxy \
    --unset https_proxy \
    --unset ftp_proxy \
    --unset rsync_proxy \
    --unset all_proxy \
    --unset no_proxy \
    --unset HTTP_PROXY \
    --unset HTTPS_PROXY \
    --unset FTP_PROXY \
    --unset RSYNC_PROXY \
    --unset ALL_PROXY \
    --unset NO_PROXY
  '';

  steam-unproxied = pkgs.steam.override {
    extraEnv = {
      http_proxy = "";
      https_proxy = "";
      ftp_proxy = "";
      rsync_proxy = "";
      all_proxy = "";
      no_proxy = "";
      HTTP_PROXY = "";
      HTTPS_PROXY = "";
      FTP_PROXY = "";
      RSYNC_PROXY = "";
      ALL_PROXY = "";
      NO_PROXY = "";
    };
  };

  protonup-qt-unproxied = pkgs.symlinkJoin {
    name = "protonup-qt-unproxied";
    paths = [ pkgs.protonup-qt ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/protonup-qt" ${unsetProxyEnv}
    '';
  };

  protonplus-unproxied = pkgs.symlinkJoin {
    name = "protonplus-unproxied";
    paths = [ pkgs.protonplus ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/protonplus" ${unsetProxyEnv}
    '';
  };
in

{
  programs.steam = {
    enable = true;
    package = steam-unproxied;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  programs.gamemode.enable = true;

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt-unproxied
    protonplus-unproxied
    wineWow64Packages.stable
    dxvk
  ];
}
