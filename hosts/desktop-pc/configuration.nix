{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./system-modules
    ../../modules/nixos
    inputs.home-manager.nixosModules.default
    inputs.nvf.nixosModules.default
    inputs.sddm-sugar-candy-nix.nixosModules.default
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.agenix.nixosModules.default
  ];
  # Agenix
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/agenix_key"
  ];
  # docker
  virtualisation.docker.enable = true;

  # Enable Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Home Manager

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    users = {
      "snrx" = {
        imports = [
          ../../hosts/desktop-pc/home.nix
        ];
      };
    };
    backupFileExtension = "backup";
  };

  # ZSH
  programs.zsh.enable = true;

  # SSH
  programs.ssh.startAgent = true;

  # GPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  # Automatize garbage collection
  nix.gc = {
    automatic = true;
    dates = "3days";
  };

  # Flatpak
  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };

  # Enables Hyprland at system-level
  programs.hyprland.enable = true;

  # Fix SDDM not starting any DE session
  services.dbus.packages = with pkgs; [ dconf ];

  # OpenRazer
  hardware.openrazer = {
    enable = true;
    users = [ "snrx" ];
  };

  environment.sessionVariables = {
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    home-manager
    inputs.agenix.packages.${pkgs.system}.default
    openrazer-daemon
    razer-cli
    nftables
    jq
  ];
  # Enabled services
  services.openssh.enable = true;

  system.autoUpgrade = {
    enable = true;
    flake = "/home/snrx/nixos";
    flags = [
      "--update-input"
      "nixpkgs"
    ];
    dates = "weekly";
    allowReboot = false;
  };

  system.stateVersion = "25.05"; # Do not change
}
