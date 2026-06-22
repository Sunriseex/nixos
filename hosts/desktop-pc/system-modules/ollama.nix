{ pkgs, ... }:
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  services.open-webui = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    (llama-cpp.override { cudaSupport = true; })
  ];
}
