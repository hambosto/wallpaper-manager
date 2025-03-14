{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wallpaper-activator = pkgs.writeShellScriptBin "wallpaper-activator" ''
    WALLPAPER_PATH=$(${pkgs.coreutils}/bin/cat "$HOME/.cache/.active_wallpaper")

    if [[ -f "$WALLPAPER_PATH" ]]; then
      ${pkgs.swww}/bin/swww img "$WALLPAPER_PATH" --transition-type random
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
    enable = lib.mkEnableOption "Enable swww-selector";
    hyprland = {
      enable = lib.mkEnableOption "Enable Hyprland color integration";
      configFile = lib.mkOption {
        type = lib.types.str;
        default = "~/.config/hypr/hyprland.conf";
        description = "Path to main Hyprland configuration file";
      };
    };
  };

  config = lib.mkIf config.programs.wallpaper-manager.enable {
    # Existing services configuration
    systemd.user.services = {
      swww = {
        Unit = {
          Description = "Wayland Wallpaper Daemon";
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
          Description = "Activate Wallpaper using swww";
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

    # Wallust configuration
    home.file.".config/wallust/wallust.toml".text = ''
      [templates]
      hypr.template = 'hyprland-colors.conf'
      hypr.target = '~/.config/hypr/hyprland-colors.conf'
    '';

    home.file.".config/wallust/templates/hyprland-colors.conf".text = ''
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

    # Hyprland integration
    wayland.windowManager.hyprland = lib.mkIf config.programs.wallpaper-manager.hyprland.enable {
      extraConfig = ''
        source = ~/.config/hypr/hyprland-colors.conf
      '';
      settings = {
        general = {
          "col.active_border" = "$color12";
          "col.inactive_border" = "$color10";
        };
      };
    };

    home.packages = [ self.packages.${pkgs.system}.default ];
  };
}
