{ pkgs, ... }:

{
  home.packages = with pkgs; [
    tree
    bat
    bc
    lsd
    yazi
    htop
    btop
    killall
    gh
    wget
    toilet
    zip
    unzip
    ffmpeg
    upower
    wl-clipboard
    fanctl
    gamemode
    tlp
    speedtest-cli
  ];
}
