{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    mutableExtensionsDir = true;

    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        golang.go
        eamodio.gitlens
        jnoortheen.nix-ide
        arrterian.nix-env-selector
        brettm12345.nixfmt-vscode
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
        ms-azuretools.vscode-docker
        github.vscode-github-actions
        redhat.vscode-yaml
        pkgs.vscode-extensions."42crunch".vscode-openapi
        davidanson.vscode-markdownlint
        usernamehw.errorlens
      ];

      userSettings = {
        "go.formatTool" = "gofumpt";
        "go.useLanguageServer" = true;
        "go.lintTool" = "golangci-lint";
        "go.toolsManagement.autoUpdate" = false;
        "gopls" = {
          "gofumpt" = true;
          "staticcheck" = true;
          "completeUnimported" = true;
          "usePlaceholders" = true;
          "analyses" = {
            "nilness" = true;
            "unusedparams" = true;
            "unusedwrite" = true;
            "useany" = true;
          };
        };
        "[go]" = {
          "editor.defaultFormatter" = "golang.go";
          "editor.formatOnSave" = true;
          "editor.codeActionsOnSave" = {
            "source.organizeImports" = "explicit";
          };
        };
      };
    };
  };
}
