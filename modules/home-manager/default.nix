{
  imports = [
    # Shell
    ./shell/cli-tools.nix
    ./shell/fastfetch.nix
    ./shell/git.nix
    ./shell/ghostty.nix
    ./shell/starship.nix
    ./shell/shell.nix
    ./ssh/client-config.nix
    # Desktop
    ./desktop/desktop-apps.nix
    ./desktop/idle.nix
    ./desktop/mpv.nix
    ./desktop/nemo.nix
    ./desktop/niri-noctalia.nix
    ./desktop/rofi.nix
    ./desktop/styling.nix
    ./desktop/virtualbox-docker-host.nix
    ./desktop/check-updates.nix
    # Apps
    ./apps/helium.nix
    ./apps/discord.nix
    # Development
    ./dev-tools.nix
    ./go-dev.nix
    ./vscodium.nix
    ./lazyvim.nix
  ];
}
