{ ... }:

{
  virtualisation.virtualbox.host.enable = true;

  services.udev.extraRules = ''
    KERNEL=="vboxdrv", OWNER="root", GROUP="vboxusers", MODE="0660"
    KERNEL=="vboxnetctl", OWNER="root", GROUP="vboxusers", MODE="0660"
  '';
}
