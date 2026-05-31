{ config, pkgs, ... }:
let
  diskCleanupScript = builtins.readFile ./scripts/disk-cleanup.sh;
  shellAliases = {
    ll = "eza -l --group-directories-first --icons --git";
    la = "eza -a --group-directories-first --icons";
    ls = "eza -la --group-directories-first --icons --git";
    lt = "eza --tree --level=2 --group-directories-first --icons";
    cat = "bat --paging=never";
    grep = "rg";
    find = "fd";
    du = "dust";
    ps = "procs";
    clr = "clear";
    yt = "youtube";
    ggl = "google";
    gpt = "chatgpt";
    nix-rebuild = "sudo nixos-rebuild switch --flake ~/nixos#desktop-pc";
    nix-build-check = "sudo nix flake check ~/nixos";
    nix-update = "nix flake update";
    nix-clear = "sudo nix-collect-garbage -d";
    disk-clean = "~/.local/bin/disk-cleanup.sh";
    disk-clean-plan = "~/.local/bin/disk-cleanup.sh --dry-run";
    disk-clean-all = "~/.local/bin/disk-cleanup.sh --docker";
    cd = "z";
  };
in
{
  programs.zoxide.enable = true;
  programs.atuin.enable = true;

  home.file.".local/bin/disk-cleanup.sh" = {
    executable = true;
    text = diskCleanupScript;
  };

  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    enableCompletion = true;
    plugins = [
      {
        name = "zsh-autocomplete";
        src = pkgs.fetchFromGitHub {
          owner = "marlonrichert";
          repo = "zsh-autocomplete";
          rev = "25.03.19";
          sha256 = "07i3wg4qh0nkqk7fsyc89s57x1fljy3bfhqncnmwd2qhcgjmmgkr";
        };
      }
    ];
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "docker-compose"
        "gitignore"
        "golang"
        "web-search"
      ];
      theme = "agnoster";
    };

    shellAliases = shellAliases;

  };

  programs.fish = {
    enable = true;
    shellAliases = shellAliases;
    interactiveShellInit = ''
      if type -q direnv
        direnv hook fish | source
      end

      if type -q fzf
        fzf --fish | source
      end

      if test -z "$FASTFETCH_DISABLED"; and type -q fastfetch
        fastfetch
      end
    '';
    functions = {
      fish_greeting = "";
      __web_search = ''
        set -l base $argv[1]
        set -e argv[1]
        set -l query (string join + -- $argv)

        if test -z "$query"
          command xdg-open $base >/dev/null 2>&1 &
        else
          command xdg-open "$base$query" >/dev/null 2>&1 &
        end
      '';
      google = "__web_search https://www.google.com/search?q= $argv";
      youtube = "__web_search https://www.youtube.com/results?search_query= $argv";
      chatgpt = "__web_search https://chatgpt.com/?q= $argv";
      nixp = "__web_search 'https://search.nixos.org/packages?channel=unstable&query=' $argv";
      perpl = "__web_search https://www.perplexity.ai/search?q= $argv";
    };
  };
}
