{ pkgs, ... }:

{
  # Define user accounts.
  users.users.snrx = {
    isNormalUser = true;
    homeMode = "0755";
    description = "Denis Vakhrushev";
    # This is a single-user admin workstation; these groups intentionally grant
    # broad local control over the system, Docker, and VirtualBox.
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "scanner"
      "lp"
      "video"
      "input"
      "audio"
      "plugdev"
      "docker"
      "vboxusers"
    ];

    shell = pkgs.zsh;

  };

  environment.shells = with pkgs; [ zsh ];

  # Sets trusted users
  nix.settings.trusted-users = [
    "root"
    "snrx"
  ];
}
