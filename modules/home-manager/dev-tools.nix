{ pkgs, ... }:
{

  home.packages = with pkgs; [
    vim
    gcc
    gnumake
    git
    shfmt
    nixfmt
    nixd
    nil
    fzf
    eza
    dust
    ripgrep
    fd
    procs
    gnupg
    direnv
    rofimoji
    docker
    nix-prefetch
    nix-prefetch-github
    codex
    nodejs
    postgresql_17
  ];

  home.sessionVariables = {
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = "${pkgs.playwright-driver.browsers}/chromium-1200/chrome-linux64/chrome";
  };
}
