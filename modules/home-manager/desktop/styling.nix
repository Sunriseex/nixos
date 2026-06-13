{ pkgs, config, ... }:

{
  # Enable GTK
  gtk = {
    enable = true;
    gtk4.theme = config.gtk.theme;
    theme = {
      package = pkgs.nordic;
      name = "Nordic";
    };
    iconTheme = {
      package = pkgs.kora-icon-theme;
      name = "kora-pgrey";
    };
    cursorTheme = {
      package = pkgs.whitesur-cursors;
      name = "WhiteSur-cursors";
      size = 24;
    };

  };

  # Enable QT
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    #style = {
    #  name = "kvantum";
    #};
  };
}
