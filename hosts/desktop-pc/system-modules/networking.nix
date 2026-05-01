{ ... }:

{
  networking.hostName = "snrx-pc"; # Define your hostname.
  networking.networkmanager.enable = true; # Enable networking

  networking.firewall = {
    enable = true;
    allowPing = true;
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      listen-address = [
        "127.0.0.1"
        "::1"
      ];
      bind-interfaces = true;
      address = [
        "/home.arpa/192.168.56.101"
        "/.home.arpa/192.168.56.101"
      ];
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
}
