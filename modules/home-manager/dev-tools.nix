{ pkgs, ... }:
{

  home.packages = with pkgs; [
    vim
    gcc
    wget
    git
    starship
    shfmt
    nixfmt
    nixd
    nil
    fzf
    bat
    eza
    dust
    ripgrep
    fd
    procs
    playerctl
    gnupg
    direnv
    rofimoji
    docker
    nix-prefetch
    nix-prefetch-github
    codex
  ];
}
