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
    enable = lib.mkEnableOption "Enable Wallpaper Manager";
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

    home.packages = [ self.packages.${pkgs.system}.default ];
  };
}
