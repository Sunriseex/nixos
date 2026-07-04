{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "mcp-servers";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-41Ir4De5cZqZkADin1Cyo8+pn2Nm2xEKmz37UIJcP8M=";
  subPackages = [
    "cmd/mcp-docker"
    "cmd/mcp-systemd"
    "cmd/mcp-nixos"
    "cmd/mcp-vbox"
    "cmd/mcp-telegram"
  ];
  meta = {
    description = "MCP servers for Docker, Systemd, NixOS, VirtualBox, and Telegram";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "mcp-docker";
  };
}
