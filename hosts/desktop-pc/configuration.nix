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
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.agenix.nixosModules.default
    inputs.silent-sddm.nixosModules.default
  ];
  # Agenix
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/agenix_key"
  ];
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

  # Shells
  programs.fish.enable = true;
  programs.zsh.enable = true;

  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      resurrect
      continuum
    ];
  };

  # SSH
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host *
        AddKeysToAgent yes

      Host VirtualBox
        AddKeysToAgent yes
        IdentityFile ~/.ssh/id_ed25519
    '';
  };

  # GPG
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    pinentryPackage = pkgs.pinentry-gnome3;
    settings = {
      default-cache-ttl = 86400;
      max-cache-ttl = 86400;
    };
  };

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=1440
    Defaults timestamp_type=global
  '';

  security.sudo.extraRules = [
    { users = [ "snrx" ];
      commands = [
        { command = "/run/current-system/sw/bin/nix-collect-garbage"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/journalctl";         options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/docker";             options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/nix";                options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/btrfs";              options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # Automatize garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Flatpak
  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };

  # Fix SDDM not starting any DE session
  services.dbus.packages = with pkgs; [ dconf ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    home-manager
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    python3
    nftables
    jq
    vicinae
  ];

  # Enabled services
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.timesyncd = {
    enable = true;
    servers = [
      "ntp1.stratum2.ru"
      "time.cloudflare.com"
      "pool.ntp.org"
    ];
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:sunriseex/nixos#desktop-pc";
    flags = [
      "--update-input"
      "nixpkgs"
    ];
    dates = "weekly";
    allowReboot = false;
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/1fc4b1b7-e4ac-434f-bb60-d9a887edd6c7";
    fsType = "btrfs";
    options = [
      "subvol=@data"
      "compress=zstd:3"
      "noatime"
      "nofail"
    ];
  };

  # Memory pressure protection
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };

  services.earlyoom = {
    enable = true;
    enableNotifications = true;

    freeMemThreshold = 10;
    freeSwapThreshold = 80;

    extraArgs = [
      "--ignore" "^(VirtualBoxVM|VBoxHeadless|qemu-system-x86|qemu-system-x86_64)$"
    ];
  };

  system.stateVersion = "25.05"; # Do not change
}
