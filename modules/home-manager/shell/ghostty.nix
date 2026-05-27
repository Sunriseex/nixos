{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;

    settings = {
      font-family = "JetBrainsMono Nerd Font Mono";
      font-style = "SemiBold";
      font-size = 14;
      background-opacity = 0.8;
      background-blur = 1;
      cursor-opacity = 1;
      selection-background = "#F5E0DC";
      selection-foreground = "#ECEFF4";
    };

  };
}
