{ ... }:
let
  GIT_GPG_SIGNING_KEY = builtins.getEnv "GIT_GPG_SIGNING_KEY";
in
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
      key = GIT_GPG_SIGNING_KEY;
      signByDefault = true;
    };

  };
}
