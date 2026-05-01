{ pkgs, ... }:

let
  proxiedBrave = pkgs.brave.override {
    commandLineArgs = "--proxy-server=socks5://127.0.0.1:10808 --proxy-bypass-list='localhost;127.0.0.1;home.arpa;*.home.arpa;192.168.56.0/24'";
  };
in
{
  home.packages = [
    proxiedBrave
  ];

  home.sessionVariables = {
    BROWSER = "brave";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "brave-browser.desktop" ];
      "text/xml" = [ "brave-browser.desktop" ];
      "application/xhtml+xml" = [ "brave-browser.desktop" ];
      "application/xml" = [ "brave-browser.desktop" ];
      "application/pdf" = [ "brave-browser.desktop" ];
      "x-scheme-handler/http" = [ "brave-browser.desktop" ];
      "x-scheme-handler/https" = [ "brave-browser.desktop" ];
      "x-scheme-handler/about" = [ "brave-browser.desktop" ];
      "x-scheme-handler/unknown" = [ "brave-browser.desktop" ];
    };
  };
}
