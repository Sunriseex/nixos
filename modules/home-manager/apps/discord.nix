{ pkgs, ... }:
let
  discord-override = pkgs.discord.override {
    commandLineArgs = "--proxy-server=socks5://127.0.0.1:10808 --disable-quic";
  };

  discord-wrapped = pkgs.symlinkJoin {
    name = "discord";
    paths = [ discord-override ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/discord" \
        --unset http_proxy \
        --unset https_proxy \
        --unset all_proxy \
        --unset HTTP_PROXY \
        --unset HTTPS_PROXY \
        --unset ALL_PROXY
    '';
  };
in
{
  programs.discord = {
    enable = true;
    package = discord-wrapped;
    settings = {
      SKIP_HOST_UPDATE = true;
    };
  };
}
