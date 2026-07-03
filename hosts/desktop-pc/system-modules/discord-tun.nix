{ pkgs, ... }:

let
  tunConfig = pkgs.writeText "discord-xray-tun.json" (builtins.toJSON {
    log = { loglevel = "warning"; };

    inbounds = [{
      tag = "tun-in";
      protocol = "tun";
      settings = {
        address = "10.0.0.1";
        mtu = 9000;
        autoRoute = true;
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

    dns = {
      servers = [
        {
          address = "https://1.1.1.1/dns-query";
          skipFallback = true;
        }
      ];
      tag = "dns";
    };

    routing = {
      domainStrategy = "IPOnDemand";
      rules = [{
        type = "field";
        inboundTag = [ "tun-in" ];
        outboundTag = "proxy";
      }];
    };
  });
in {
  systemd.services.discord-xray-tun = {
    description = "xray TUN proxy for Discord (network namespace)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      ${pkgs.iproute2}/bin/ip netns add discord 2>/dev/null || true
      mkdir -p /etc/netns/discord
      echo "nameserver 1.1.1.1" > /etc/netns/discord/resolv.conf
      cp ${tunConfig} /run/discord-xray-tun/config.json
    '';

    script = ''
      exec ${pkgs.iproute2}/bin/ip netns exec discord \
        ${pkgs.xray}/bin/xray run -c /run/discord-xray-tun/config.json
    '';

    postStop = ''
      ${pkgs.iproute2}/bin/ip netns del discord 2>/dev/null || true
    '';

    serviceConfig = {
      RuntimeDirectory = "discord-xray-tun";
      RuntimeDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "3s";
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_ADMIN" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_ADMIN" ];
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "snrx" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nsenter --net=/var/run/netns/discord *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "discord-proxied" ''
      unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
      unset ftp_proxy rsync_proxy no_proxy NO_PROXY RSYNC_PROXY FTP_PROXY
      exec sudo -n /run/current-system/sw/bin/nsenter \
        --net=/var/run/netns/discord \
        /home/snrx/.nix-profile/bin/discord "$@"
    '')
  ];
}
