{ pkgs, ... }:
{
  home.packages = with pkgs; [
    go
    gopls
    delve
    golangci-lint
  ];
}
