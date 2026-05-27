{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      gcc
      git
      ripgrep
      fd
      lua-language-server
      stylua
      go_1_26
      gopls
      gofumpt
      gotests
      gomodifytags
      impl
      delve
      golangci-lint
      golangci-lint-langserver
    ];
  };

  xdg.configFile."nvim".source = ./lazyvim;
}
