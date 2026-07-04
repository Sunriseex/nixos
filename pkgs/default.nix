pkgs:
let
  mcp-servers = pkgs.callPackage ./mcp-servers { };
  mcp-bin = name: pkgs.runCommand name
    { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; }
    ''
      mkdir -p $out/bin
      makeBinaryWrapper ${mcp-servers}/bin/${name} $out/bin/${name}
    '';
in
{
  awakened-poe-trade = pkgs.callPackage ./awakened-poe-trade { };
  pob-poe1 = pkgs.callPackage ./pob-poe1 {
    wine = pkgs.wineWow64Packages.stable;
  };
  pob-poe2 = pkgs.callPackage ./pob-poe2 {
    wine = pkgs.wineWow64Packages.stable;
  };
  llm-checker = pkgs.callPackage ./llm-checker { };

  inherit mcp-servers;

  mcp-docker = mcp-bin "mcp-docker";
  mcp-systemd = mcp-bin "mcp-systemd";
  mcp-nixos = mcp-bin "mcp-nixos";
  mcp-vbox = mcp-bin "mcp-vbox";
  mcp-telegram = mcp-bin "mcp-telegram";

  ssh-mcp = pkgs.callPackage ../scripts/ssh-mcp { };
}
