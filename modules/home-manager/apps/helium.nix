{ ... }:

{
  programs.helium = {
    enable = true;
    flags = [
      "--proxy-server=socks5://127.0.0.1:10808"
      "--proxy-bypass-list=localhost;127.0.0.1;home.arpa;*.home.arpa;192.168.56.0/24"
    ];
  };

  home.sessionVariables = {
    BROWSER = "helium";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "helium.desktop" ];
      "text/xml" = [ "helium.desktop" ];
      "application/xhtml+xml" = [ "helium.desktop" ];
      "application/xml" = [ "helium.desktop" ];
      "application/pdf" = [ "helium.desktop" ];
      "x-scheme-handler/http" = [ "helium.desktop" ];
      "x-scheme-handler/https" = [ "helium.desktop" ];
      "x-scheme-handler/about" = [ "helium.desktop" ];
      "x-scheme-handler/unknown" = [ "helium.desktop" ];
    };
  };
}
