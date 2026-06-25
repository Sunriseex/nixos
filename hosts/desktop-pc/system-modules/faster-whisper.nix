{ pkgs, ... }:

let
  whisperModel = "large-v3";
  modelCache = "/var/lib/faster-whisper/models";
  runScript = pkgs.writeShellScript "faster-whisper-run" ''
    exec ${pkgs.docker}/bin/docker run --rm --name faster-whisper \
      --device nvidia.com/gpu=all \
      --network host \
      -v ${modelCache}:/root/.cache \
      -e FASTER_WHISPER_MODEL=${whisperModel} \
      -e FASTER_WHISPER_DEVICE=cuda \
      -e FASTER_WHISPER_COMPUTE_TYPE=float16 \
      -e FASTER_WHISPER_HOST=0.0.0.0 \
      -e FASTER_WHISPER_PORT=8000 \
      -e FASTER_WHISPER_BEAM_SIZE=5 \
      -e FASTER_WHISPER_BEST_OF=5 \
      -e FASTER_WHISPER_VAD_FILTER=true \
      -e FASTER_WHISPER_TEMPERATURE=0 \
      -e OLLAMA_URL=http://localhost:11434/api/generate \
      -e FASTER_WHISPER_IDLE_UNLOAD_SECONDS=300 \
      loodka-faster-whisper:cuda
  '';
in {
  systemd.tmpfiles.rules = [
    "d ${modelCache} 0755 root root -"
  ];

  systemd.services.faster-whisper = {
    description = "Faster-Whisper STT server with CUDA";
    after = [ "docker.service" "network.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      ${pkgs.docker}/bin/docker rm -f faster-whisper 2>/dev/null || true
    '';

    serviceConfig = {
      ExecStart = "${runScript}";
      ExecStop = "${pkgs.docker}/bin/docker stop faster-whisper";
      Restart = "on-failure";
      RestartSec = "10s";
      TimeoutStartSec = "300s";
    };
  };
}
