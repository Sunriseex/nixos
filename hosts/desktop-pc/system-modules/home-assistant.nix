# modules/apps/home-assistant.nix
{ pkgs, ... }:

{
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless.enable = false; # Важно отключить rootless режим

  systemd.services.home-assistant = {
    description = "Home Assistant Docker Container";
    after = [
      "network.target"
      "docker.service"
    ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      ExecStart = ''
        ${pkgs.docker}/bin/docker run \
          --name homeassistant \
          --privileged \
          --restart=unless-stopped \
          -v /var/lib/homeassistant:/config \
          -v /etc/localtime:/etc/localtime:ro \
          --network=host \
          ghcr.io/home-assistant/home-assistant:stable
      '';
      ExecStop = "${pkgs.docker}/bin/docker stop homeassistant";
      ExecStopPost = "${pkgs.docker}/bin/docker rm homeassistant";
    };

    preStart = ''
      image="ghcr.io/home-assistant/home-assistant:stable"

      mkdir -p /var/lib/homeassistant

      # Make start idempotent even if stale container remained after a crash.
      ${pkgs.docker}/bin/docker rm -f homeassistant >/dev/null 2>&1 || true

      # Pull only when image is absent, so regular service restarts stay fast.
      if ! ${pkgs.docker}/bin/docker image inspect "$image" >/dev/null 2>&1; then
        ${pkgs.docker}/bin/docker pull "$image"
      fi
    '';
    environment = {
      TZ = "Europe/Moscow"; # Укажите вашу временную зону
    };
  };

  networking.firewall.allowedTCPPorts = [ 8123 ];
}
