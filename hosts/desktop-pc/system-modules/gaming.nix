{ pkgs, ... }:

let
  protonup-qt-unproxied = pkgs.symlinkJoin {
    name = "protonup-qt-unproxied";
    paths = [ pkgs.protonup-qt ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/protonup-qt" \
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
  };

  protonplus-unproxied = pkgs.symlinkJoin {
    name = "protonplus-unproxied";
    paths = [ pkgs.protonplus ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/protonplus" \
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
  };
in

{
  programs.steam = {
    enable = true;
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
