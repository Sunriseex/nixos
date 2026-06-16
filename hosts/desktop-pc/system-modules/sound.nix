{ pkgs, ... }:

{
  # Enable sound with pipewire
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
        # Отключаем неиспользуемые аудиоустройства
        # Оставляем только: G435 → вывод (наушники), fifine → ввод (микрофон)
        "10-alsa-rules" = {
          "monitor.alsa.rules" = [
            # NVIDIA HDMI (GP106 High Definition Audio Controller)
            {
              matches = [{ "device.name" = "alsa_card.pci-0000_05_00.1"; }];
              apply_properties = { "device.disabled" = true; };
            }
            # S/PDIF + аналоговый вход материнской платы
            {
              matches = [{ "device.name" = "alsa_card.pci-0000_07_00.4"; }];
              apply_properties = { "device.disabled" = true; };
            }
            # C922 Pro Stream Webcam — микрофон
            {
              matches = [{ "device.name" = "~alsa_card.usb-046d_C922_Pro_Stream_Webcam*"; }];
              apply_properties = { "device.disabled" = true; };
            }
            # fifine — отключаем выход (оставляем только микрофон)
            {
              matches = [{ "node.name" = "alsa_output.usb-3142_fifine_Microphone-00.analog-stereo"; }];
              apply_properties = { "node.disabled" = true; };
            }
            # G435 — отключаем микрофон наушников (оставляем только вывод)
            {
              matches = [{ "node.name" = "alsa_input.usb-Logitech_G_series_G435_Wireless_Gaming_Headset_202105190004-00.mono-fallback"; }];
              apply_properties = { "node.disabled" = true; };
            }
          ];
        };
      };
    };
  };
  services.pulseaudio = {
    enable = false;
  };

  environment.systemPackages = with pkgs; [
    alsa-utils
    pulseaudio
    pwvucontrol
    wireplumber
  ];
}
