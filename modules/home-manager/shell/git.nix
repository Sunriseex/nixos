{ ... }:
{
  programs.git = {
    enable = true;
    diff-so-fancy.enable = true;
    userName = "Sunriseex";
    userEmail = "norealpwnz@gmail.com";
    extraConfig = {
      safe.directory = "/home/snrx/.config/git";
      init.defaultBranch = "main";
    };

    signing = {
      key = "";
      signByDefault = true;
    };

  };
}
