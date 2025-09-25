{ pkgs, ... }:
{
  programs.zoxide.enable = true;
  programs.atuin.enable = true;

  programs.zsh = {
    enable = true;
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
      cd = "z";
    };

  };

}
