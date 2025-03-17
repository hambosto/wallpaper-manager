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

    pywal = {
      enable = lib.mkEnableOption "Enable pywal integration for theme generation";
      extraArgs = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Extra arguments to pass to pywal";
      };
      enableHyprlandIntegration = lib.mkEnableOption "Enable pywal integration with Hyprland";
      enableFishIntegration = lib.mkEnableOption "Enable pywal integration with Fish shell";
      enableKittyIntegration = lib.mkEnableOption "Enable pywal integration with Kitty terminal";
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

    xdg.configFile = lib.mkIf config.programs.wallpaper-manager.pywal.enable {
      ".config/wal/templates/colors-hyprland.conf".text = ''
        $background = rgb({background.strip})
        $foreground = rgb({foreground.strip})
        $color0 = rgb({color0.strip})
        $color1 = rgb({color1.strip})
        $color2 = rgb({color2.strip})
        $color3 = rgb({color3.strip})
        $color4 = rgb({color4.strip})
        $color5 = rgb({color5.strip})
        $color6 = rgb({color6.strip})
        $color7 = rgb({color7.strip})
        $color8 = rgb({color8.strip})
        $color9 = rgb({color9.strip})
        $color10 = rgb({color10.strip})
        $color11 = rgb({color11.strip})
        $color12 = rgb({color12.strip})
        $color13 = rgb({color13.strip})
        $color14 = rgb({color14.strip})
        $color15 = rgb({color15.strip})
      '';
    };

    programs.kitty =
      lib.mkIf
        (
          config.programs.kitty.enable
          && config.programs.wallpaper-manager.pywal.enable
          && config.programs.wallpaper-manager.pywal.enableKittyIntegration
        )
        {
          extraConfig = lib.mkForce ''
            include ${config.xdg.cacheHome}/wal/colors-kitty.conf
          '';
        };

    programs.fish =
      lib.mkIf
        (
          config.programs.fish.enable
          && config.programs.wallpaper-manager.pywal.enable
          && config.programs.wallpaper-manager.pywal.enableFishIntegration
        )
        {
          # FIXME: This is messy. I have to clear my Home Manager Fish interactive shell init
          # because the existing configuration will be overridden by this config.
          # You should disable Stylix Fish if enabled using `stylix.targets.fish.enable = false;`.
          # Sorry, everyone, for forcing you to add Fastfetch.
          # For now, this only applies to the Fish shell, but it will be added to other shells soon.
          interactiveShellInit = lib.mkForce ''
            set fish_greeting # Disable greeting
            ${pkgs.coreutils}/bin/cat ${config.xdg.cacheHome}/wal/sequences
            ${lib.getExe pkgs.fastfetch}
          '';
        };

    wayland.windowManager.hyprland =
      lib.mkIf
        (
          config.wayland.windowManager.hyprland.enable
          && config.programs.wallpaper-manager.pywal.enable
          && config.programs.wallpaper-manager.pywal.enableHyprlandIntegration
        )
        {
          settings = {
            source = [ "${config.xdg.cacheHome}/wal/colors-hyprland.conf" ];
            general = {
              "col.active_border" = lib.mkForce "$color11";
              "col.inactive_border" = lib.mkForce "rgba(ffffffff)";
            };
          };
        };

    home.packages = [ self.packages.${pkgs.system}.default ];
  };
}
