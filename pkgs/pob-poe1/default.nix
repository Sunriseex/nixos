{
  lib,
  fetchurl,
  stdenv,
  unzip,
  wine,
  copyDesktopItems,
  makeDesktopItem,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pob-poe1";
  version = "2.65.0";

  src = fetchurl {
    url = "https://github.com/PathOfBuildingCommunity/PathOfBuilding/releases/download/v${finalAttrs.version}/PathOfBuildingCommunity-Portable.zip";
    hash = "sha256-M52r6iLFVkNr0fgHYkBe0rkQBQDrbpL43nxKz3LPNUg=";
  };

  nativeBuildInputs = [ unzip copyDesktopItems ];

  dontUnpack = true;

  desktopItems = [
    (makeDesktopItem {
      name = "pob-poe1";
      desktopName = "Path of Building (PoE1)";
      comment = "Offline build planner for Path of Exile 1 (Community Fork)";
      exec = "pob-poe1";
      terminal = false;
      type = "Application";
      icon = "pob-poe1";
      categories = [ "Game" ];
      keywords = [ "poe" "pob" "path" "exile" ];
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/pob-poe1
    unzip $src -d $out/lib/pob-poe1
    mv "$out/lib/pob-poe1/Path of Building.exe" "$out/lib/pob-poe1/pob-poe1.exe"
    chmod +x "$out/lib/pob-poe1/pob-poe1.exe"
    echo "$out/lib/pob-poe1" > "$out/lib/pob-poe1/.store-path"
    runHook postInstall
  '';

  postFixup = ''
    echo '#!${stdenv.shell}' -e > $out/bin/pob-poe1
    echo "STORE_SRC='$out/lib/pob-poe1'" >> $out/bin/pob-poe1
    echo "WINE='${lib.getExe wine}'" >> $out/bin/pob-poe1
    cat >> $out/bin/pob-poe1 << 'WRAPPER'
LOCAL_DIR="$HOME/.local/share/pob-poe1"
STORE_PATH_FILE="$LOCAL_DIR/.store-path"

needs_copy=false
if [ ! -f "$STORE_PATH_FILE" ]; then
  needs_copy=true
elif [ "$(cat "$STORE_PATH_FILE" 2>/dev/null)" != "$STORE_SRC" ]; then
  needs_copy=true
fi

if [ "$needs_copy" = true ]; then
  rm -rf "$LOCAL_DIR"
  mkdir -p "$LOCAL_DIR"
  cp -r "$STORE_SRC"/. "$LOCAL_DIR/"
  echo "$STORE_SRC" > "$LOCAL_DIR/.store-path"
fi

for var in http_proxy https_proxy ftp_proxy rsync_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY RSYNC_PROXY ALL_PROXY NO_PROXY; do
  unset "$var"
done

exec "$WINE" "$LOCAL_DIR/pob-poe1.exe" "$@"
WRAPPER
    chmod +x $out/bin/pob-poe1
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Offline build planner for Path of Exile 1 (Community Fork)";
    homepage = "https://github.com/PathOfBuildingCommunity/PathOfBuilding";
    changelog = "https://github.com/PathOfBuildingCommunity/PathOfBuilding/releases/tag/v${finalAttrs.version}";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pob-poe1";
  };
})
