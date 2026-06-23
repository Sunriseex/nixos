{
  pkgs,
  inputs,
  ...
}:

let
  localPkgs = import ../../../pkgs pkgs;
in

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
    godot
    prismlauncher # Minecraft launcher
    localPkgs.awakened-poe-trade # Path of Exile trade overlay
    localPkgs.pob-poe1 # Path of Building PoE1 (via Wine)
    localPkgs.pob-poe2 # Path of Building PoE2 (via Wine)
    heroic # Epic Games/GOG launcher
    umu-launcher # Unified launcher for Proton outside Steam
    v2rayn
    xray
    freecad
    synology-drive-client
    localsend # Cross-platform FOSS alternative to Airdrop
    easyeffects # Audio effects for PipeWire applications
    czkawka-full # App to remove duplicates and unnecessary files
    losslesscut-bin # Lossless video/audio editing
    textpieces # Text processing utility
    identity # Image and videos comparison tool
    fsearch # Fast indexed file search, similar to Everything
    piper # Mouse configuration app
    bluez
    bluez-tools
    polychromatic
    razergenie
    input-remapper
    mousai
    flameshot
    wf-recorder
    protonplus
  ];

  services.flatpak.packages = [
    {
      appId = "com.github.d4nj1.tlpui";
      origin = "flathub";
    }
    {
      appId = "net.lutris.Lutris";
      origin = "flathub";
    }
    {
      appId = "com.usebottles.bottles";
      origin = "flathub";
    }
  ];

}
