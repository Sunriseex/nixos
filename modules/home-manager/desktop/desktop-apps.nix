{
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.nix-flatpak.homeManagerModules.nix-flatpak ];

  home.packages = with pkgs; [
    obsidian
    spotify
    gimp
    qimgv # Image viewer
    pavucontrol
    libreoffice
    keepassxc
    telegram-desktop
    blueman
    kdePackages.kdenlive # Editing software
    obs-studio
    godot
    v2rayn
    xray
    vscode
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
    bluez
    bluez-tools
    protonup-qt
  ];

  services.flatpak.packages = [
    {
      appId = "com.github.d4nj1.tlpui";
      origin = "flathub";
    }
  ];

}
