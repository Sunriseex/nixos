{ pkgs, ... }:

{
  programs.niri = {
    enable = true;
    useNautilus = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
    config = {
      common = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;

  nix.settings = {
    #extra-substituters = [ "https://noctalia.cachix.org" ];
    #extra-trusted-public-keys = [
    # "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    #];
  };
}
