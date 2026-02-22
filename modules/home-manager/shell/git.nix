{
  config,
  ...
}:

{
  programs.diff-so-fancy = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Sunriseex";
        email = "norealpwnz@gmail.com";
      };
      safe.directory = "${config.home.homeDirectory}/nixos";
      init.defaultBranch = "main";
    };

    signing = {
      key = "02F1649EAED0CAC4";
      signByDefault = true;
    };

  };

}
