{ pkgs, ... }:

let
  idleSuspendVisuals = pkgs.writeShellApplication {
    name = "idle-suspend-visuals";
    runtimeInputs = with pkgs; [
      niri
      razer-cli
    ];
    text = ''
      set -euo pipefail

      niri msg action power-off-monitors || true
      razer-cli -b 0 || true
    '';
  };

  idleResumeVisuals = pkgs.writeShellApplication {
    name = "idle-resume-visuals";
    runtimeInputs = with pkgs; [
      niri
      razer-cli
    ];
    text = ''
      set -euo pipefail

      niri msg action power-on-monitors || true
      razer-cli --restore || true
      razer-cli -b 100 || true
    '';
  };

  cursorLocator = pkgs.writeShellApplication {
    name = "cursor-locator";
    runtimeInputs = with pkgs; [
      coreutils
      highlight-pointer
      procps
    ];
    text = ''
      set -euo pipefail

      pkill -x highlight-pointer >/dev/null 2>&1 || true
      timeout 2.5s highlight-pointer \
        --released-color "#0a84ff" \
        --pressed-color "#34c759" \
        --outline 3 \
        --radius 28 \
        --opacity 0.78 \
        --auto-hide-highlight \
        --hide-timeout 1.8
    '';
  };
in
{
  home.packages = [
    pkgs.highlight-pointer
    cursorLocator
    idleSuspendVisuals
    idleResumeVisuals
  ];

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 900;
        command = "${idleSuspendVisuals}/bin/idle-suspend-visuals";
        resumeCommand = "${idleResumeVisuals}/bin/idle-resume-visuals";
      }
    ];
  };
}
