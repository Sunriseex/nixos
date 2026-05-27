{
  imports = [
    # Shell
    ./shell/cli-tools.nix
    ./shell/fastfetch.nix
    ./shell/git.nix
    ./shell/kitty.nix
    ./shell/ghostty.nix
    ./shell/starship.nix
    ./shell/shell.nix
    # Desktop
    ./desktop/desktop-apps.nix
    ./desktop/idle.nix
    ./desktop/mpv.nix
    ./desktop/nemo.nix
    ./desktop/niri-noctalia.nix
    ./desktop/rofi.nix
    ./desktop/styling.nix
    ./desktop/codex-limit-rings.nix
    ./desktop/virtualbox-docker-host.nix
    # Apps
    ./apps/helium.nix
    ./apps/discord.nix
    ./apps/librewolf.nix
    # Development
    ./dev-tools.nix
    ./go-dev.nix
    ./vscodium.nix
    ./lazyvim.nix
  ];
}
