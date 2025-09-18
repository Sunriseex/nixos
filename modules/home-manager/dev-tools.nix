{ pkgs, ... }:
{

  home.packages = with pkgs; [
    vim
    wget
    git
    starship
    shfmt
    nixfmt
    nixd
    nil
    go
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
  ];
}
