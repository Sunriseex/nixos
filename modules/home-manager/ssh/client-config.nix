{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ForwardAgent = "no";
        ServerAliveCountMax = 3;
        ServerAliveInterval = 0;
      };

      VM = {
        HostName = "192.168.56.101";
        User = "sunriseex";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
      };

      VirtualBox = {
        HostName = "192.168.56.101";
        User = "sunriseex";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519";
      };

      FI1 = {
        HostName = "217.60.62.234";
        User = "snrx";
        Port = 2197;
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      laptop = {
        HostName = "192.168.1.80";
        User = "snrx";
        Port = 22;
        IdentityFile = "~/.ssh/id_ed25519_laptop";
      };

      LV1 = {
        HostName = "104.252.19.202";
        User = "snrx";
        Port = 2198;
        IdentityFile = "~/.ssh/id_ed25519_vm";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };
}
