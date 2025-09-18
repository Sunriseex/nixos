{ pkgs, ... }:
{
  hardware.openrazer = {
    enable = true;
    users = [ "snrx" ];
  };
  environment.systemPackages = with pkgs; [
    openrazer-daemon
    razer-cli
    polychromatic
  ];
}
