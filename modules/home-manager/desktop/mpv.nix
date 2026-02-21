{ pkgs, ... }:

{
  programs.mpv = {
    enable = true;

    package = (
      pkgs.mpv.override {
        scripts = with pkgs.mpvScripts; [
          uosc
          sponsorblock
        ];

        # вместо mpv = ... используем mpv-unwrapped = ...
        mpv-unwrapped = pkgs.mpv-unwrapped.override {
          waylandSupport = true;
        };
      }
    );

    config = {
      profile = "gpu-hq";
      ytdl-format = "bestvideo+bestaudio";
      hwdec = "auto-safe";
      vo = "gpu";
      gpu-context = "wayland";
    };
  };
}
