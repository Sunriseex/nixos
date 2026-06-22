{ lib, stdenv, python3, openssh, makeWrapper }:

stdenv.mkDerivation {
  pname = "ssh-mcp";
  version = "1.0.0";
  src = ./.;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp $src/server.py $out/bin/ssh-mcp
    chmod +x $out/bin/ssh-mcp
    runHook postInstall
  '';
  postFixup = ''
    wrapProgram $out/bin/ssh-mcp \
      --prefix PATH : ${lib.makeBinPath [ python3 openssh ]}
  '';
  meta = {
    description = "MCP server for SSH remote management";
    platforms = lib.platforms.linux;
  };
}
