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
      general {
          col.active_border = rgb({{color1 | saturate(0.6) | strip}}) rgb({{color2 | saturate(0.6) | strip}}) rgb({{color3 | saturate(0.6) | strip}}) rgb({{color4 | saturate(0.6) | strip}}) rgb({{color5 | saturate(0.6) | strip}}) rgb({{color6 | saturate(0.6) | strip}})
          col.inactive_border = rgba({{color0}})
      }
    '';

    # Hyprland integration
    wayland.windowManager.hyprland = lib.mkIf config.programs.wallpaper-manager.hyprland.enable {
      extraConfig = ''
        source = ${config.xdg.configHome}/hypr/hyprland-colors.conf
      '';
    };

    home.packages = [ self.packages.${pkgs.system}.default ];
  };
}
