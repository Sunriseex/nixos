{ pkgs, ... }:
{

  home.packages = with pkgs; [
    vim
    gcc
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
  ];
}
