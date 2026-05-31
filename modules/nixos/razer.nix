{ pkgs, ... }:
{
  hardware.openrazer = {
    enable = true;
    users = [ "snrx" ];
    devicesOffOnScreensaver = true;
  };
  environment.systemPackages = with pkgs; [
    openrazer-daemon
    razer-cli
    polychromatic
  ];
}
