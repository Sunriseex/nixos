{ pkgs, ... }:

let
  redirectPort = "12345";
  discordUdpPorts = "1024:65535";
  fwmark = "0x1";
  table = "100";

  xrayConfig = pkgs.writeText "discord-udp-xray.json" (builtins.toJSON {
    log = { loglevel = "warning"; };

    inbounds = [{
      tag = "discord-udp-redirect";
      listen = "0.0.0.0";
      port = 12345;
      protocol = "dokodemo-door";
      settings = {
        network = "udp";
        followRedirect = true;
      };
      streamSettings = {
        sockopt = { tproxy = "redirect"; };
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
      domainStrategy = "IPIfNonMatch";
      rules = [{
        type = "field";
        inboundTag = [ "discord-udp-redirect" ];
        outboundTag = "proxy";
      }];
    };
  });
in {
  systemd.services.discord-udp-xray = {
    description = "Transparent Xray proxy for Discord UDP";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    preStart = ''
      cp ${xrayConfig} "$RUNTIME_DIRECTORY/config.json"
      ${pkgs.xray}/bin/xray run -test -c "$RUNTIME_DIRECTORY/config.json"
    '';

    serviceConfig = {
      ExecStart = "${pkgs.xray}/bin/xray run -c /run/discord-udp-xray/config.json";
      RuntimeDirectory = "discord-udp-xray";
      RuntimeDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "3s";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };
  };

  networking.firewall = {
    extraCommands = ''
      ${pkgs.iptables}/bin/iptables -w -t nat -D OUTPUT -p udp -m multiport --dports ${discordUdpPorts} -m addrtype ! --dst-type LOCAL -j REDIRECT --to-ports ${redirectPort} 2>/dev/null || true
      ${pkgs.iptables}/bin/iptables -w -t mangle -D POSTROUTING -p udp -m multiport --dports ${discordUdpPorts} -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || true
      ${pkgs.iptables}/bin/iptables -w -t mangle -D POSTROUTING -p tcp --dport 80 -m connbytes --connbytes-dir original --connbytes-mode packets --connbytes 1:6 -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || true
      ${pkgs.iptables}/bin/iptables -w -t mangle -D POSTROUTING -p tcp --dport 443 -m connbytes --connbytes-dir original --connbytes-mode packets --connbytes 1:6 -m mark ! --mark 0x40000000/0x40000000 -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || true

      ${pkgs.iproute2}/bin/ip rule add fwmark ${fwmark}/${fwmark} table ${table} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip route replace local 0.0.0.0/0 dev lo table ${table}

      ${pkgs.iptables}/bin/iptables -w -t mangle -C OUTPUT -p udp -m multiport --dports ${discordUdpPorts} -m addrtype ! --dst-type LOCAL -j MARK --set-mark ${fwmark} 2>/dev/null \
        || ${pkgs.iptables}/bin/iptables -w -t mangle -A OUTPUT -p udp -m multiport --dports ${discordUdpPorts} -m addrtype ! --dst-type LOCAL -j MARK --set-mark ${fwmark}

      ${pkgs.iptables}/bin/iptables -w -t mangle -C PREROUTING -p udp -m mark --mark ${fwmark}/${fwmark} -j TPROXY --on-port ${redirectPort} --tproxy-mark ${fwmark}/${fwmark} 2>/dev/null \
        || ${pkgs.iptables}/bin/iptables -w -t mangle -A PREROUTING -p udp -m mark --mark ${fwmark}/${fwmark} -j TPROXY --on-port ${redirectPort} --tproxy-mark ${fwmark}/${fwmark}
    '';

    extraStopCommands = ''
      ${pkgs.iptables}/bin/iptables -w -t nat -D OUTPUT -p udp -m multiport --dports ${discordUdpPorts} -m addrtype ! --dst-type LOCAL -j REDIRECT --to-ports ${redirectPort} 2>/dev/null || true
      ${pkgs.iptables}/bin/iptables -w -t mangle -D OUTPUT -p udp -m multiport --dports ${discordUdpPorts} -m addrtype ! --dst-type LOCAL -j MARK --set-mark ${fwmark} 2>/dev/null || true
      ${pkgs.iptables}/bin/iptables -w -t mangle -D PREROUTING -p udp -m mark --mark ${fwmark}/${fwmark} -j TPROXY --on-port ${redirectPort} --tproxy-mark ${fwmark}/${fwmark} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip route flush table ${table} 2>/dev/null || true
      ${pkgs.iproute2}/bin/ip rule del fwmark ${fwmark}/${fwmark} table ${table} 2>/dev/null || true
    '';
  };
}
