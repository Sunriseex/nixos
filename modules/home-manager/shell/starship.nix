{ ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    settings = {

      #"$schema" = "https://starship.rs/config-schema.json";

      format = "[](nord0)\$os\$username\[@](bg:nord0 fg:nord4)\$hostname\[](bg:nord1 fg:nord0)\$directory\[](fg:nord1 bg:nord2)\$git_branch\$git_status\[](fg:nord2 bg:nord3)\$c\$rust\$golang\$nodejs\$php\$java\$kotlin\$haskell\$python\[ ](fg:nord3)\$line_break$character";

      #[](fg:nord3 bg:nord10)\
      #$docker_context\

      palette = "nord";

      palettes.nord = {
        # Dark to light gray
        nord0 = "#2E3440";
        nord1 = "#3B4252";
        nord2 = "#434C5E";
        nord3 = "#4C566A";
        # Light gray to white
        nord4 = "#D8DEE9";
        nord5 = "#E5E9F0";
        nord6 = "#ECEFF4";
        # Light blue to blue
        nord7 = "#8FBCBB";
        nord8 = "#88C0D0";
        nord9 = "#81A1C1";
        nord10 = "#5E81AC";
        # Mixed colors (red, orange, yellow, green purple)
        nord11 = "#BF616A";
        nord12 = "#D08770";
        nord13 = "#EBCB8B";
        nord14 = "#A2BE8A";
        nord15 = "#B48EAD";
      };

      os = {
        style = "bg:nord0 fg:nord10";
        disabled = false;

        symbols = {
          #NixOS = "";
          Windows = "󰍲";
          Ubuntu = "󰕈";
          SUSE = "";
          Raspbian = "󰐿";
          Mint = "󰣭";
          Macos = "";
          Manjaro = "";
          Linux = "󰌽";
          Gentoo = "󰣨";
          Fedora = "󰣛";
          Alpine = "";
          Amazon = "";
          Android = "";
          Arch = "󰣇";
          Artix = "󰣇";
          CentOS = "";
          Debian = "󰣚";
          Redhat = "󱄛";
          RedHatEnterprise = "󱄛";
        };
      };

      username = {
        show_always = true;
        style_user = "bg:nord0 fg:nord4";
        style_root = "bg:nord0 fg:nord4";
        format = "[$user]($style)";
      };

      hostname = {
        ssh_only = false;
        ssh_symbol = " ";
        trim_at = ".";
        format = "[$hostname$ssh_symbol ]($style)";
        style = "bg:nord0 fg:nord4";
      };

      directory = {
        style = "bg:nord1 fg:nord4";
        format = "[ $path ]($style)";
        read_only = " 󰌾 ";
        read_only_style = "bg:nord1 fg:nord11";
        truncation_length = 3;
        truncation_symbol = "…/";

        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = "󰝚 ";
          "Pictures" = " ";
          "Developer" = "󰲋 ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:nord2 fg:nord4";
        format = "[ $symbol $branch ]($style)";
      };

      git_status = {
        style = "bg:nord2 fg:nord4";
        format = "[$all_status$ahead_behind ]($style)";
      };

      # Programming languages
      nodejs = {
        symbol = "";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      c = {
        symbol = " ";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      golang = {
        symbol = " ";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      php = {
        symbol = "";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      java = {
        symbol = " ";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      kotlin = {
        symbol = "";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      haskell = {
        symbol = "";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      python = {
        symbol = "";
        style = "bg:nord3 fg:nord4";
        format = "[ $symbol ($version) ]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:nord4";
        format = "[[ $symbol( $context) ]]($style)";
      };

      line_break.disabled = false;

      character = {
        disabled = false;
        success_symbol = "[](bold fg:nord14)";
        error_symbol = "[](bold fg:nord11)";
      };
    };
  };
}
