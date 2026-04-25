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
    ./desktop/mpv.nix
    ./desktop/nemo.nix
    ./desktop/niri-noctalia.nix
    ./desktop/rofi.nix
    ./desktop/styling.nix
    ./desktop/virtualbox-docker-host.nix
    # Apps
    ./apps/brave.nix
    ./apps/discord.nix
    ./apps/librewolf.nix
    # Development
    ./dev-tools.nix
    ./go-dev.nix
  ];
}
