{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.wallpaper-manager;

  wallpaper-activator = pkgs.writeShellScriptBin "wallpaper-activator" ''
    WALLPAPER_PATH=$(${pkgs.coreutils}/bin/cat "${config.xdg.cacheHome}/.active_wallpaper")

    if [[ -f "$WALLPAPER_PATH" ]]; then
      ${lib.getExe pkgs.swww} img "$WALLPAPER_PATH" --transition-type outer
      echo "Wallpaper set: $WALLPAPER_PATH"
      exit 0
    else
      echo "Wallpaper file not found: $WALLPAPER_PATH"
      exit 1
    fi
  '';
in
{
  #
  # Options
  #
  options.programs.wallpaper-manager = {
    enable = mkEnableOption "Wallpaper Manager for managing desktop backgrounds";

    defaultTransition = mkOption {
      type = types.str;
      default = "outer";
      description = "Default transition effect for wallpaper changes";
    };

    wallust = {
      enable = mkEnableOption "Wallust integration for color scheme generation";

      backend = mkOption {
        type = types.enum [
          "kmeans"
          "colorz"
          "wal"
        ];
        default = "kmeans";
        description = "Color extraction backend to use";
      };

      colorSpace = mkOption {
        type = types.enum [
          "lab"
          "rgb"
          "hsv"
          "labmixed"
        ];
        default = "labmixed";
        description = "Color space to use for palette generation";
      };

      palette = mkOption {
        type = types.enum [
          "dark16"
          "light16"
        ];
        default = "dark16";
        description = "Palette type to generate";
      };

      threshold = mkOption {
        type = types.int;
        default = 11;
        description = "Threshold value for color generation";
      };

      integrations = {
        hyprland = mkEnableOption "Wallust integration with Hyprland";
        kitty = mkEnableOption "Wallust integration with Kitty terminal";
        fish = mkEnableOption "Wallust integration with Fish shell";
        rofi = mkEnableOption "Wallust integration with Rofi";
      };
    };
  };

  #
  # Implementation
  #
  config = mkIf cfg.enable (mkMerge [
    # Base configuration
    {
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
            RestartSec = 5;
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
            Restart = "on-failure";
            RestartSec = 3;
          };
        };
      };

      home.packages = with pkgs; [ self.packages.${system}.default ];
    }

    # Wallust Integration
    (mkIf cfg.wallust.enable {
      home.packages = [ pkgs.wallust ];

      xdg.configFile = {
        "wallust/wallust.toml" = {
          text = ''
            backend = "${cfg.wallust.backend}"
            color_space = "${cfg.wallust.colorSpace}"
            palette = "${cfg.wallust.palette}"
            threshold = ${toString cfg.wallust.threshold}

            [templates]
            ${optionalString cfg.wallust.integrations.hyprland ''
              hypr.template = "hyprland-colors.conf"
              hypr.target = "${config.xdg.configHome}/hypr/themes/hyprland-colors.conf"
            ''}
            ${optionalString cfg.wallust.integrations.kitty ''
              kitty.template = "kitty-colors.conf"
              kitty.target = "${config.xdg.configHome}/kitty/themes/kitty-colors.conf"
            ''}
            ${optionalString cfg.wallust.integrations.rofi ''
              rofi.template = "rofi-colors.rasi"
              rofi.target = "${config.xdg.configHome}/rofi/themes/rofi-colors.rasi"
            ''}
          '';
        };

        "wallust/templates/hyprland-colors.conf" = mkIf cfg.wallust.integrations.hyprland {
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

        "wallust/templates/kitty-colors.conf" = mkIf cfg.wallust.integrations.kitty {
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

          "wallust/templates/rofi-colors.rasi" = mkIf cfg.wallust.integrations.rofi {
            text = ''
              * {{
                  color0:     {color0};
                  color1:     {color1};
                  color2:     {color2};
                  color3:     {color3};
                  color4:     {color4};
                  color5:     {color5};
                  color6:     {color6};
                  color7:     {color7};
                  color8:     {color8};
                  color9:     {color9};
                  color10:    {color10};
                  color11:    {color11};
                  color12:    {color12};
                  color13:    {color13};
                  color14:    {color14};
                  color15:    {color15};
                }}
            '';
          };
        };
      };
    })

    # Kitty Integration
    (mkIf (config.programs.kitty.enable && cfg.wallust.enable && cfg.wallust.integrations.kitty) {
      programs.kitty.extraConfig = mkForce ''
        include ${config.xdg.configHome}/kitty/themes/kitty-colors.conf
      '';
    })

    # Fish Integration
    (mkIf (config.programs.fish.enable && cfg.wallust.enable && cfg.wallust.integrations.fish) {
      programs.fish.interactiveShellInit = mkBefore ''
        # Apply terminal colors from Wallust
        if test -f ${config.xdg.cacheHome}/wallust/sequences
          ${pkgs.coreutils}/bin/cat ${config.xdg.cacheHome}/wallust/sequences
        end
      '';
    })

    # Hyprland Integration
    (mkIf
      (
        config.wayland.windowManager.hyprland.enable
        && cfg.wallust.enable
        && cfg.wallust.integrations.hyprland
      )
      {
        wayland.windowManager.hyprland = {
          settings = {
            source = [ "${config.xdg.configHome}/hypr/themes/hyprland-colors.conf" ];
            general = {
              "col.active_border" = mkForce "$color12";
              "col.inactive_border" = mkForce "$color10";
            };
            decoration = {
              shadow = {
                color = mkForce "$color12";
                color_inactive = mkForce "$color10";
              };
            };
            group = {
              "col.border_active" = mkForce "$color15";
              groupbar = {
                "col.active" = mkForce "$color0";
              };
            };
          };
        };
      }
    )
  ]);
}
