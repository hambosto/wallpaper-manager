{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wallpaper-activator = pkgs.writeShellScriptBin "wallpaper-activator" ''
    WALLPAPER_PATH=$(${pkgs.coreutils}/bin/cat "${config.xdg.cacheHome}/.active_wallpaper")

    if [[ -f "$WALLPAPER_PATH" ]]; then
      ${lib.getExe pkgs.swww} img "$WALLPAPER_PATH" --transition-type random
      echo "Wallpaper set: $WALLPAPER_PATH"
      exit 0
    else
      echo "Wallpaper file not found: $WALLPAPER_PATH"
      exit 1
    fi
  '';
in
{
  options.programs.wallpaper-manager = {
    enable = lib.mkEnableOption "Enable Wallpaper Manager";

    wallust = {
      enable = lib.mkEnableOption "Enable wallust integration for color generation";
      hyprland.enable = lib.mkEnableOption "Enable wallust integration with Hyprland";
      fish.enable = lib.mkEnableOption "Enable wallust integration with Fish shell";
      kitty.enable = lib.mkEnableOption "Enable wallust integration with Kitty terminal";
    };
  };

  config = lib.mkIf config.programs.wallpaper-manager.enable {

    systemd.user.services = {
      swww = {
        Unit = {
          Description = "SWWW Wallpaper Daemon";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.swww}/bin/swww-daemon";
          ExecStop = "${pkgs.swww}/bin/swww kill";
          Restart = "on-failure";
        };
      };

      wallpaper-activator = {
        Unit = {
          Description = "Activate Wallpaper using SWWW";
          Requires = [ "swww.service" ];
          After = [ "swww.service" ];
          PartOf = [ "swww.service" ];
        };
        Install.WantedBy = [ "swww.service" ];
        Service = {
          Type = "oneshot";
          ExecStart = "${wallpaper-activator}/bin/wallpaper-activator";
        };
      };
    };

    xdg.configFile = {
      "wallust/wallust.toml" = lib.mkIf config.programs.wallpaper-manager.wallust.enable {
        text = ''
          backend = "kmeans"
          color_space = "labmixed"
          palette = "dark16"
          threshold = 11
          [templates]
          hypr.template = "hyprland-colors.conf"
          hypr.target = "${config.xdg.configHome}/hypr/themes/wallust.conf"
          kitty.template = "kitty-colors.conf"
          kitty.target = "${config.xdg.configHome}/kitty/themes/kitty-colors.conf"
        '';
      };
      "wallust/templates/hyprland-colors.conf" =
        lib.mkIf config.programs.wallpaper-manager.wallust.enable
          {
            text = ''
              $wallpaper = {{wallpaper}}
              $background = rgb({{background | strip}})
              $foreground = rgb({{foreground | strip}})
              $color0 = rgb({{color0 | strip}})
              $color1 = rgb({{color1 | strip}})
              $color2 = rgb({{color2 | strip}})
              $color3 = rgb({{color3 | strip}})
              $color4 = rgb({{color4 | strip}})
              $color5 = rgb({{color5 | strip}})
              $color6 = rgb({{color6 | strip}})
              $color7 = rgb({{color7 | strip}})
              $color8 = rgb({{color8 | strip}})
              $color9 = rgb({{color9 | strip}})
              $color10 = rgb({{color10 | strip}})
              $color11 = rgb({{color11 | strip}})
              $color12 = rgb({{color12 | strip}})
              $color13 = rgb({{color13 | strip}})
              $color14 = rgb({{color14 | strip}})
              $color15 = rgb({{color15 | strip}})
            '';
          };
      "wallust/templates/kitty-colors.conf" = lib.mkIf config.programs.wallpaper-manager.wallust.enable {
        text = ''
          foreground         {{foreground}}
          background         {{background}}
          cursor             {{cursor}}

          active_tab_foreground     {{background}}
          active_tab_background     {{foreground}}
          inactive_tab_foreground   {{foreground}}
          inactive_tab_background   {{background}}

          active_border_color   {{foreground}}
          inactive_border_color {{background}}
          bell_border_color     {{color1}}

          color0      {{color0}}
          color1      {{color1}}
          color2      {{color2}}
          color3      {{color3}}
          color4      {{color4}}
          color5      {{color5}}
          color6      {{color6}}
          color7      {{color7}}
          color8      {{color8}}
          color9      {{color9}}
          color10     {{color10}}
          color11     {{color11}}
          color12     {{color12}}
          color13     {{color13}}
          color14     {{color14}}
          color15     {{color15}}
        '';
      };
    };

    programs.kitty =
      lib.mkIf
        (
          config.programs.kitty.enable
          && config.programs.wallpaper-manager.wallust.enable
          && config.programs.wallpaper-manager.wallust.kitty.enable
        )
        {
          extraConfig = lib.mkForce ''
            include ${config.xdg.configHome}/kitty/themes/kitty-colors.conf
          '';
        };

    programs.fish =
      lib.mkIf
        (
          config.programs.fish.enable
          && config.programs.wallpaper-manager.wallust.enable
          && config.programs.wallpaper-manager.wallust.fish.enable
        )
        {
          interactiveShellInit = ''
            set fish_greeting # Disable greeting
            ${pkgs.coreutils}/bin/cat ${config.xdg.cacheHome}/wallust/sequences
            ${lib.getExe pkgs.fastfetch}
          '';
        };

    wayland.windowManager.hyprland =
      lib.mkIf
        (
          config.wayland.windowManager.hyprland.enable
          && config.programs.wallpaper-manager.wallust.enable
          && config.programs.wallpaper-manager.wallust.hyprland.enable
        )
        {
          settings = {
            source = [ "${config.xdg.configHome}/hypr/themes/wallust.conf" ];
            general = {
              "col.active_border" = lib.mkForce "$color11";
              "col.inactive_border" = lib.mkForce "rgba(ffffffff)";
            };
          };
        };

    home.packages = [ self.packages.${pkgs.system}.default ];
  };
}
