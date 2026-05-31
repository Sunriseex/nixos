{ pkgs, ... }:
{
  home.packages = with pkgs; [
    go_1_26
    gopls
    gofumpt
    gotests
    gomodifytags
    impl
    delve
    golangci-lint
    golangci-lint-langserver
    gotestsum
  ];
}
