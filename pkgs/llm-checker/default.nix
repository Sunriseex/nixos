{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "llm-checker";
  version = "3.7.5";

  src = fetchFromGitHub {
    owner = "Pavelevich";
    repo = "llm-checker";
    rev = "fcf966963935d5d8fab43562c4900155321d50f1";
    hash = "sha256-HhO3awNnY2Q876MpKBWv7/ARQ5HyIlH6Jo3yGlcGb7g=";
  };

  npmDepsHash = "sha256-gRGE14box9frROvcbQiZYxS3K78uiJdBLBGHvfhd4E8=";

  dontNpmBuild = true;

  meta = {
    description = "Advanced CLI tool that scans your hardware and tells you exactly which LLM models you can run locally";
    homepage = "https://github.com/Pavelevich/llm-checker";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "llm-checker";
    platforms = lib.platforms.linux;
  };
}
