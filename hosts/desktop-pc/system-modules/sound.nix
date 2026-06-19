{ pkgs, inputs, ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
      extraConfig = {
        bluetoothEnhancements = {
          "monitor.bluez.properties" = {
            "bluez5.enable-hw-volume" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-sbc-xq" = true;
            "bluez5.roles" = [
              "a2dp_sink"
              "a2dp_source"
              "bap_sink"
              "bap_source"
              "hfp_hf"
              "hfp_ag"
              "hsp_hs"
              "hsp_ag"
            ];
          };
        };
        "10-alsa-rules" = {
          "monitor.alsa.rules" = [
            {
              matches = [{ "device.name" = "alsa_card.pci-0000_05_00.1"; }];
              apply_properties = { "device.disabled" = true; };
            }
            {
              matches = [{ "device.name" = "alsa_card.pci-0000_07_00.4"; }];
              apply_properties = { "device.disabled" = true; };
            }
            {
              matches = [{ "device.name" = "~alsa_card.usb-046d_C922_Pro_Stream_Webcam*"; }];
              apply_properties = { "device.disabled" = true; };
            }
            {
              matches = [{ "node.name" = "alsa_output.usb-3142_fifine_Microphone-00.analog-stereo"; }];
              apply_properties = { "node.disabled" = true; };
            }
            {
              matches = [{ "node.name" = "alsa_input.usb-Logitech_G_series_G435_Wireless_Gaming_Headset_202105190004-00.mono-fallback"; }];
              apply_properties = { "node.disabled" = true; };
            }
          ];
        };
      };
    };
  };

  systemd.user.services.pw-duck = {
    after = [ "pipewire-session-manager.service" "graphical-session.target" ];
    wants = [ "pipewire-session-manager.service" ];
    description = "pw-duck audio ducking";
    path = [ pkgs.pipewire pkgs.pulseaudio ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 3;
      ExecStart = "${inputs.pw-duck.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/pw-duck";
    };
    wantedBy = [ "default.target" ];
  };

  services.pulseaudio = {
    enable = false;
  };

  environment.systemPackages = with pkgs; [
    alsa-utils
    pulseaudio
    pwvucontrol
    wireplumber
    inputs.pw-duck.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
