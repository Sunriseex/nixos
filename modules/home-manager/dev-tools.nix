{ pkgs, ... }:
{

  home.packages = with pkgs; [
    vim
    air
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
    pnpm
    yarn
    bun
    playwright-test
    prettier
    prettierd
    eslint_d
    typescript-language-server
    vscode-langservers-extracted
    postgresql_17
    claude-code
    opencode
  ];

  home.sessionVariables = {
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = "${pkgs.playwright-driver.browsers}/chromium-1200/chrome-linux64/chrome";
  };
}
