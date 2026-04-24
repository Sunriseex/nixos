{ pkgs, ... }:
{
  programs.discord = {
    enable = true;
    package = pkgs.discord.override {
      commandLineArgs = "--proxy-server=socks5://127.0.0.1:10808";
    };

    settings = {
      SKIP_HOST_UPDATE = true;
    };
  };
}
