{
  pkgs,
  inputs,
  ...
}:

let
  rusty-path-of-building-unproxied = pkgs.symlinkJoin {
    name = "rusty-path-of-building-unproxied";
    paths = [ pkgs.rusty-path-of-building ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/rusty-path-of-building" \
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
    prismlauncher # Minecraft launcher
    awakened-poe-trade # Path of Exile trade overlay
    rusty-path-of-building-unproxied # Path of Building
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
