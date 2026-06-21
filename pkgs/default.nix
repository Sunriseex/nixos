pkgs: {
  awakened-poe-trade = pkgs.callPackage ./awakened-poe-trade { };
  pob-poe2 = pkgs.callPackage ./pob-poe2 {
    wine = pkgs.wineWow64Packages.stable;
  };

  llm-checker = pkgs.callPackage ./llm-checker { };
}
