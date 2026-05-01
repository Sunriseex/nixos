{ ... }:

{
  virtualisation.virtualbox.host.enable = true;

  networking.extraHosts = ''
    192.168.56.101 docker-host.vm
  '';

  networking.firewall.interfaces.vboxnet0.allowedTCPPorts = [ 10808 ];

  services.udev.extraRules = ''
    KERNEL=="vboxdrv", OWNER="root", GROUP="vboxusers", MODE="0660"
    KERNEL=="vboxnetctl", OWNER="root", GROUP="vboxusers", MODE="0660"
  '';
}
