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
  pname = "pob-poe2";
  version = "0.21.0";

  src = fetchurl {
    url = "https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/releases/download/v${finalAttrs.version}/PathOfBuildingCommunity-PoE2-Portable.zip";
    hash = "sha256-xjNaC5BuM1aBVAjNXs2b/bEB95EtN7oAwaNEUF+Ka34=";
  };

  nativeBuildInputs = [ unzip copyDesktopItems ];

  dontUnpack = true;

  desktopItems = [
    (makeDesktopItem {
      name = "pob-poe2";
      desktopName = "Path of Building (PoE2)";
      comment = "Offline build planner for Path of Exile 2 (Community Fork)";
      exec = "pob-poe2";
      terminal = false;
      type = "Application";
      icon = "pob-poe2";
      categories = [ "Game" ];
      keywords = [ "poe" "pob" "path" "exile" ];
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/pob-poe2
    unzip $src -d $out/lib/pob-poe2
    mv "$out/lib/pob-poe2/Path of Building-PoE2.exe" "$out/lib/pob-poe2/pob-poe2.exe"
    chmod +x "$out/lib/pob-poe2/pob-poe2.exe"
    echo "$out/lib/pob-poe2" > "$out/lib/pob-poe2/.store-path"
    runHook postInstall
  '';

  postFixup = ''
    echo '#!${stdenv.shell}' -e > $out/bin/pob-poe2
    echo "STORE_SRC='$out/lib/pob-poe2'" >> $out/bin/pob-poe2
    echo "WINE='${lib.getExe wine}'" >> $out/bin/pob-poe2
    cat >> $out/bin/pob-poe2 << 'WRAPPER'
LOCAL_DIR="$HOME/.local/share/pob-poe2"
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

exec "$WINE" "$LOCAL_DIR/pob-poe2.exe" "$@"
WRAPPER
    chmod +x $out/bin/pob-poe2
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Offline build planner for Path of Exile 2 (Community Fork)";
    homepage = "https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2";
    changelog = "https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/releases/tag/v${finalAttrs.version}";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pob-poe2";
  };
})
