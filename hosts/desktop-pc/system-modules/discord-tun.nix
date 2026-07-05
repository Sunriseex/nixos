{ pkgs, ... }:

let
  xrayConfig = pkgs.writeText "discord-xray.json" (builtins.toJSON {
    log = { loglevel = "warning"; };

    inbounds = [{
      tag = "socks-in";
      protocol = "socks";
      listen = "127.0.0.1";
      port = 10809;
      settings = {
        auth = "noauth";
        udp = true;
      };
      sniffing = {
        enabled = true;
        destOverride = [ "http" "tls" ];
      };
    }];

    outbounds = [{
      tag = "proxy";
      protocol = "vless";
      settings = {
        vnext = [{
          address = "lv1node.soon.it";
          port = 8443;
          users = [{
            id = "25788ada-ab4c-47ab-a00e-cbba5edb4a8e";
            flow = "xtls-rprx-vision";
            encryption = "none";
          }];
        }];
      };
      streamSettings = {
        network = "tcp";
        security = "reality";
        realitySettings = {
          fingerprint = "firefox";
          serverName = "lv1node.soon.it";
          publicKey = "tpjqqi2FPGZ1nWHbRxka800TFg-J1_OMvJ04oUC4kkA";
          shortId = "b0dbd85b5a3fb62a";
        };
      };
    }];

    routing = {
      rules = [{
        type = "field";
        inboundTag = [ "socks-in" ];
        outboundTag = "proxy";
      }];
    };
  });
in {
  systemd.services.discord-xray = {
    description = "xray SOCKS5 proxy for Discord";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      mkdir -p /run/discord-xray
      cp ${xrayConfig} /run/discord-xray/config.json
    '';

    script = ''
      exec ${pkgs.xray}/bin/xray run -c /run/discord-xray/config.json
    '';

    serviceConfig = {
      RuntimeDirectory = "discord-xray";
      RuntimeDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "3s";
      DynamicUser = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "discord-proxied" ''
      unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
      unset ftp_proxy rsync_proxy no_proxy NO_PROXY RSYNC_PROXY FTP_PROXY
      export ALL_PROXY=socks5://127.0.0.1:10809
      export all_proxy=socks5://127.0.0.1:10809
      exec /home/snrx/.nix-profile/bin/discord "$@"
    '')
  ];
}
