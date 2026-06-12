{ pkgs, ... }:
{
  services.ollama = {
    enable = true;
  };

  services.open-webui = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    llama-cpp
  ];
}
