{
  config,
  pkgs,
  ...
}:

let
  settingsPath = "${config.home.homeDirectory}/nixos/modules/home-manager/vscode/settings-linux.json";
in

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = true;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        golang.go
        catppuccin.catppuccin-vsc-icons
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
        jnoortheen.nix-ide
        redhat.vscode-yaml
        bradlc.vscode-tailwindcss
        ms-azuretools.vscode-docker
        ms-vscode.makefile-tools
        github.vscode-github-actions
        github.vscode-pull-request-github
        eamodio.gitlens
        usernamehw.errorlens
        davidanson.vscode-markdownlint
      ];
    };
  };

  xdg.configFile."Code/User/settings.json" = {
    force = true;
    source = config.lib.file.mkOutOfStoreSymlink settingsPath;
  };
}
