{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  home.packages = with pkgs; [
    obsidian
    discord
    spotify
    gimp
    qimgv # Image viewer
    pavucontrol
    libreoffice
    bitwarden-desktop
    blueman
    kdePackages.kdenlive # Editing software
    obs-studio
    godot
    aseprite
    freecad
    synology-drive-client
    localsend # Cross-platform FOSS alternative to Airdrop
    easyeffects # Audio effects for PipeWire applications
    czkawka-full # App to remove duplicates and unnecessary files
    losslesscut-bin # Lossless video/audio editing
    textpieces # Text processing utility
    identity # Image and videos comparison tool
    piper # Mouse configuration app
  ];

 services.flatpak.packages = [
    { appId = "com.github.d4nj1.tlpui"; origin = "flathub";  }
  ];

}
