{ ... }:
{
  programs.zoxide.enable = true;
  programs.atuin.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;

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
      lla = "eza -la --group-directories-first --icons --git";
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
      nix-rebuild = "sudo nixos-rebuild switch --flake ~/nixos#msi-laptop";
      cd = "z";
    };

  };

}
