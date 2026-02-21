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
    ./desktop/hypridle.nix
    ./desktop/hyprland.nix
    ./desktop/hyprlock.nix
    ./desktop/hyprpaper.nix
    ./desktop/mpv.nix
    ./desktop/nemo.nix
    ./desktop/rofi.nix
    ./desktop/styling.nix
    ./desktop/waybar.nix
    ./desktop/wlogout.nix
    # Apps
    # ./apps/discord.nix
    ./apps/firefox.nix
    ./apps/librewolf.nix
    # Development
    ./dev-tools.nix
    ./go-dev.nix
  ];
}
