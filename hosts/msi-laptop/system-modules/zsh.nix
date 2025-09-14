{ pkgs, ... }:
{
  programs = {
    zsh = {
      enable = true;
      ohMyZsh = {
        enable = true;
      };
      autosuggestions = {
        enable = true;
      };
      syntaxHighlighting = {
        enable = true;
      };

      shellInit = ''
        ZSH_WEB_SEARCH_ENGINES=(
          nixp "https://search.nixos.org/packages?channel=unstable&query="
          perpl "https://www.perplexity.ai/search?q="
        )

        eval "$(direnv hook zsh)"
        eval "$(atuin init zsh)"
        eval "$(zoxide init zsh)"
        source <(fzf --zsh)
         if [[ -z "$FASTFETCH_DISABLED" ]]; then
          fastfetch
        fi
      '';

    };

  };
  environment.shells = [ pkgs.zsh ];
}
