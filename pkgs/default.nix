pkgs: {
  awakened-poe-trade = pkgs.callPackage ./awakened-poe-trade { };
  pob-poe1 = pkgs.callPackage ./pob-poe1 {
    wine = pkgs.wineWow64Packages.stable;
  };

  pob-poe2 = pkgs.callPackage ./pob-poe2 {
    wine = pkgs.wineWow64Packages.stable;
  };

  llm-checker = pkgs.callPackage ./llm-checker { };

  ssh-mcp = pkgs.callPackage ../scripts/ssh-mcp { };
}
