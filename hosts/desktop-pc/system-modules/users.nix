{ pkgs, ... }:

{
  # Define user accounts.
  users.users.snrx = {
    isNormalUser = true;
    homeMode = "0755";
    description = "Denis Vakhrushev";
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
    ];

    shell = pkgs.zsh;

  };

  environment.shells = with pkgs; [ zsh ];
  environment.systemPackages = with pkgs; [
    eza
    fzf
  ];

  # Sets trusted users
  nix.settings.trusted-users = [
    "root"
    "snrx"
  ];
}
