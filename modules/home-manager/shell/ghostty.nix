{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;

    settings = {
      font-family = "FiraCode Nerd Font Mono";
      font-style = "Bold";
      font-size = 14;
      background-opacity = 0.1;
      background-blur = 1;
      cursor-opacity = 1;
      selection-background = "#F5E0DC";
      selection-foreground = "#ECEFF4";
    };

  };
}
