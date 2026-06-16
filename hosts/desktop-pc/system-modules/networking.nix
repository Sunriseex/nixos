{ ... }:

let
  proxy = "socks5://127.0.0.1:10808";
  noProxy = "127.0.0.1,localhost,::1,home.arpa,.home.arpa,192.168.56.0/24,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
in
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

  networking.proxy = {
    default = proxy;
    allProxy = proxy;
    noProxy = noProxy;
  };

  environment.variables = {
    http_proxy = proxy;
    https_proxy = proxy;
    ftp_proxy = proxy;
    rsync_proxy = proxy;
    all_proxy = proxy;
    no_proxy = noProxy;
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    FTP_PROXY = proxy;
    RSYNC_PROXY = proxy;
    ALL_PROXY = proxy;
    NO_PROXY = noProxy;
  };
}
