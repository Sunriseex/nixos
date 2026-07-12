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
        autoRoute = false;
      };
    }];
    outbounds = [
      {
        tag = "socks-proxy";
        protocol = "socks";
        settings = {
          servers = [{
            address = "10.0.1.1";
            port = 10808;
          }];
        };
      }
    ];
    routing = {
      domainStrategy = "IPIfNonMatch";
      domainMatcher = "hybrid";
      rules = [
        {
          type = "field";
          inboundTag = [ "tun-in" ];
          outboundTag = "socks-proxy";
        }
      ];
    };
    fakedns = [
      {
        ipPool = "198.18.0.0/15";
        poolSize = 65535;
      }
    ];
    sniffing = {
      enabled = true;
      destOverride = [ "http" "tls" "fakedns" ];
      metadataOnly = false;
    };
  });

  outboundConfig = pkgs.writeText "discord-xray-outbound.json" (builtins.toJSON {
    log = { loglevel = "warning"; };
    inbounds = [{
      tag = "socks-in";
      protocol = "socks";
      listen = "10.0.1.1";
      port = 10808;
      settings = {
        udp = true;
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
  });
in {
  networking.firewall.allowedTCPPorts = [ 10808 ];

  systemd.tmpfiles.rules = [
    "d /etc/netns/discord 0755 root root -"
    "f /etc/netns/discord/resolv.conf 0644 root root - nameserver 1.1.1.1"
    "d /run/netns 0755 root root -"
  ];

  # Oneshot — creates namespace + veth pair outside sandbox
  systemd.services.discord-netns = {
    description = "Create Discord network namespace + veth pair";
    before = [ "discord-xray-outbound.service" "discord-xray-tun.service" ];
    wantedBy = [ "discord-xray-outbound.service" "discord-xray-tun.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "discord-netns-setup" ''
        set -e
        ${pkgs.iproute2}/bin/ip netns add discord 2>/dev/null || true

        # Create veth pair if not exists
        ${pkgs.iproute2}/bin/ip link show veth0 2>/dev/null || \
          ${pkgs.iproute2}/bin/ip link add veth0 type veth peer name veth1

        # Move veth1 into discord namespace
        ${pkgs.iproute2}/bin/ip link set veth1 netns discord 2>/dev/null || true

        # Configure host side
        ${pkgs.iproute2}/bin/ip addr add 10.0.1.1/24 dev veth0 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip link set veth0 up

        # Configure namespace side
        ${pkgs.iproute2}/bin/ip netns exec discord \
          ${pkgs.iproute2}/bin/ip addr add 10.0.1.2/24 dev veth1 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip netns exec discord \
          ${pkgs.iproute2}/bin/ip link set veth1 up
        ${pkgs.iproute2}/bin/ip netns exec discord \
          ${pkgs.iproute2}/bin/ip link set lo up
      '';
      ExecStop = pkgs.writeShellScript "discord-netns-teardown" ''
        ${pkgs.iproute2}/bin/ip link del veth0 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip netns del discord 2>/dev/null || true
      '';
    };
  };

  # xray outbound — host namespace, SOCKS5 inbound, VLESS outbound to proxy
  systemd.services.discord-xray-outbound = {
    description = "xray outbound proxy for Discord (host namespace)";
    after = [ "network.target" "discord-netns.service" ];
    wants = [ "discord-netns.service" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      cp ${outboundConfig} /run/discord-xray-outbound/config.json
    '';

    serviceConfig = {
      RuntimeDirectory = "discord-xray-outbound";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${pkgs.xray}/bin/xray run -c /run/discord-xray-outbound/config.json";
      Restart = "on-failure";
      RestartSec = "3s";
      DynamicUser = true;
    };
  };

  # xray TUN — discord namespace, TUN inbound, SOCKS5 outbound via veth
  systemd.services.discord-xray-tun = {
    description = "xray TUN proxy for Discord (network namespace)";
    after = [ "discord-netns.service" "discord-xray-outbound.service" ];
    wants = [ "discord-netns.service" "discord-xray-outbound.service" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      cp ${tunConfig} /run/discord-xray-tun/config.json
    '';

    script = ''
      exec ${pkgs.iproute2}/bin/ip netns exec discord \
        ${pkgs.bash}/bin/bash -c '
          set -e
          PATH=${pkgs.iproute2}/bin:${pkgs.coreutils}/bin:$PATH

          ip link set lo up

          ${pkgs.xray}/bin/xray run -c /run/discord-xray-tun/config.json &
          XRAY_PID=''${!}

          for i in $(seq 1 20); do
            if ip link show xray0 >/dev/null 2>&1; then
              break
            fi
            sleep 0.5
          done

          ip addr replace 10.0.0.1/24 dev xray0
          ip link set xray0 up
          ip route del 1.1.1.1/32 dev veth1 2>/dev/null || true
          ip route replace default dev xray0

          wait ''${XRAY_PID}
        '
    '';

    serviceConfig = {
      RuntimeDirectory = "discord-xray-tun";
      RuntimeDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "3s";
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_ADMIN" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_ADMIN" ];
      ProtectSystem = "full";
      ProtectHome = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ "/etc/resolv.conf" ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "snrx" ];
      commands = [
        {
          command = "${pkgs.iproute2}/bin/ip netns exec discord *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "discord-proxied" ''
      unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
      unset ftp_proxy rsync_proxy no_proxy NO_PROXY RSYNC_PROXY FTP_PROXY
      exec sudo -n ${pkgs.iproute2}/bin/ip netns exec discord \
        sudo -u snrx \
        /home/snrx/.nix-profile/bin/discord "$@"
    '')
  ];
}
