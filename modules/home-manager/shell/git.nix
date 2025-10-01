{
  ...
}:

{
  programs.git = {
    enable = true;
    diff-so-fancy.enable = true;
    userName = "Sunriseex";
    userEmail = "norealpwnz@gmail.com";
    extraConfig = {
      safe.directory = "/home/snrx/nixos";
      init.defaultBranch = "main";

    };

    signing = {
      key = "02F1649EAED0CAC4";
      signByDefault = true;
    };

  };

}
