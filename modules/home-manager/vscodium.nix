{ pkgs, ... }:

let
  marketplaceExtension =
    {
      publisher,
      name,
      version,
      sha256,
    }:
    pkgs.vscode-utils.extensionFromVscodeMarketplace {
      inherit
        publisher
        name
        version
        sha256
        ;
    };
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
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
        github.vscode-pull-request-github
        redhat.vscode-yaml
        pkgs.vscode-extensions."42crunch".vscode-openapi
        davidanson.vscode-markdownlint
        usernamehw.errorlens
        bradlc.vscode-tailwindcss
        prisma.prisma
        ms-vscode.makefile-tools
        ms-vscode.live-server
        (marketplaceExtension {
          publisher = "openai";
          name = "chatgpt";
          version = "26.5519.32039";
          sha256 = "sha256-hJhmLn3AvmY3X3RlbKlpeBX94w8PPm1cuPb3GNvgL/g=";
        })
        (marketplaceExtension {
          publisher = "ms-playwright";
          name = "playwright";
          version = "1.1.19";
          sha256 = "sha256-N2U+KvmqslmjXSpHovIbT/iVbSV6JrTu1UsoiolW9/Y=";
        })
        (marketplaceExtension {
          publisher = "mtxr";
          name = "sqltools";
          version = "0.28.5";
          sha256 = "sha256-2JgBRMaNU3einOZ0POfcc887HCScu6myETTLoJMS6o8=";
        })
        (marketplaceExtension {
          publisher = "mtxr";
          name = "sqltools-driver-pg";
          version = "0.5.7";
          sha256 = "sha256-fbQsKnkBz11ZTZ2v7Y9bQ9GHPjactUoB98LeNRKeOkY=";
        })
        (marketplaceExtension {
          publisher = "humao";
          name = "rest-client";
          version = "0.25.1";
          sha256 = "sha256-DSzZ9wGB0IVK8gYOzLLbT03WX3xSmR/IUVZkDzcczKc=";
        })
      ];

      userSettings = {
        "editor.fontFamily" = "'JetBrainsMono Nerd Font Mono', 'JetBrains Mono', monospace";
        "editor.fontWeight" = "600";
        "terminal.integrated.fontFamily" = "JetBrainsMono Nerd Font Mono";
        "terminal.integrated.fontWeight" = "600";
        "workbench.colorTheme" = "Default Dark Modern";
        "go.formatTool" = "gofumpt";
        "go.useLanguageServer" = true;
        "go.lintTool" = "golangci-lint";
        "go.toolsManagement.autoUpdate" = false;
        "typescript.tsdk" = "web/node_modules/typescript/lib";
        "eslint.validate" = [
          "javascript"
          "javascriptreact"
          "typescript"
          "typescriptreact"
        ];
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
        "[typescript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "editor.formatOnSave" = true;
        };
        "[typescriptreact]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "editor.formatOnSave" = true;
        };
      };
    };
  };
}
