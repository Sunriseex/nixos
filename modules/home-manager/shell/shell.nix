{ config, pkgs, ... }:
let
  diskCleanupScript = builtins.readFile ./scripts/disk-cleanup.sh;
  recordScreenScript = builtins.readFile ./scripts/record-screen.sh;
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
    disk-clean-all = "~/.local/bin/disk-cleanup.sh --docker --aggressive";
    disk-clean-auto = "~/.local/bin/disk-cleanup.sh --yes";
    disk-clean-data = "~/.local/bin/disk-cleanup.sh --target /mnt/data";
    cd = "z";
    # claude and opencode defined as fish functions below (avoid alias recursion)
    record-screen = "record-screen";
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

    shellAliases = shellAliases // {
      claude = "http_proxy=http://localhost:10808 https_proxy=http://localhost:10808 TZ=Europe/Riga LANG=en_US.UTF-8 claude";
      opencode = "http_proxy=http://localhost:10808 https_proxy=http://localhost:10808 TZ=Europe/Riga LANG=en_US.UTF-8 opencode";
    };

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

      if not ssh-add -l >/dev/null 2>&1
        ssh-add -q ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_laptop ~/.ssh/id_ed25519_server ~/.ssh/id_ed25519_vm 2>/dev/null
      end
    '';
    functions = {
      fish_greeting = "";
      claude = "set -lx http_proxy http://localhost:10808\nset -lx https_proxy http://localhost:10808\nset -lx TZ Europe/Riga\nset -lx LANG en_US.UTF-8\ncommand claude $argv\n";
      opencode = "set -lx http_proxy http://localhost:10808\nset -lx https_proxy http://localhost:10808\nset -lx TZ Europe/Riga\nset -lx LANG en_US.UTF-8\ncommand opencode $argv\n";
      __web_search = '''
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

  home.file.".local/bin/record-screen" = {
    executable = true;
    text = recordScreenScript;
  };
}
