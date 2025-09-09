{ config, pkgs, ... }:

{
  # Define user accounts.
  users.users.snrx = {
    isNormalUser = true;
    description = "Denis Vakhrushev";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  # Sets trusted users
  nix.settings.trusted-users = [ "root" "snrx"];
}
