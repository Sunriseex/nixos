{
  config,
  lib,
  pkgs,
  ...
}:

let
  nvimConfigPath = "${config.home.homeDirectory}/nixos/modules/home-manager/lazyvim";
in

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    sideloadInitLua = true;
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
      nil
      nixd
      nixfmt
      nodejs
      typescript-language-server
      vscode-langservers-extracted
      eslint_d
      prettier
      prettierd
    ];
  };

  home.activation.nvimWritableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.config/nvim"
    source="${nvimConfigPath}"

    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config"

    if [ -L "$target" ] || [ ! -e "$target" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$target"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -s "$source" "$target"
    elif [ "$(${pkgs.coreutils}/bin/readlink -f "$target")" != "$source" ]; then
      backup="$target.hm-backup-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv "$target" "$backup"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -s "$source" "$target"
    fi
  '';
}
