{ ... }:

{
  programs.niri = {
    enable = true;
    useNautilus = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;

  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };
}
