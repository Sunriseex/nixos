{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    font-awesome
    nerd-fonts.caskaydia-cove
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [
        "JetBrainsMono Nerd Font"
        "JetBrainsMono Nerd Font Mono"
      ];
      sansSerif = [
        "JetBrainsMono Nerd Font"
        "JetBrainsMono Nerd Font Propo"
      ];
      serif = [
        "JetBrainsMono Nerd Font"
        "JetBrainsMono Nerd Font Propo"
      ];
    };
    localConf = ''
      <match target="pattern">
        <test name="family" compare="contains">
          <string>JetBrainsMono Nerd Font</string>
        </test>
        <edit name="weight" mode="assign">
          <const>semibold</const>
        </edit>
      </match>
    '';
  };
}
