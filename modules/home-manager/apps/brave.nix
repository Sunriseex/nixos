{ pkgs, ... }:

{
  home.packages = [
    pkgs.brave
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
