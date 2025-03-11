{ pkgs }:

{
  buildDeps = with pkgs; [
    pkg-config
    makeWrapper
  ];

  libraryDeps = with pkgs; [
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXinerama
    xorg.libXrandr
    xorg.libXxf86vm
    libGL
  ];

  meta = {
    pname = "wallpaper-manager";
    version = "1.0";
    description = "A lightweight wallpaper manager for Wayland, integrating with swww for smooth transitions and persistent wallpaper selection.";
    homepage = "https://github.com/hambosto/wallpaper-manager";
    license = pkgs.lib.licenses.mit;
    maintainers = with pkgs.lib.maintainers; [ hambosto ];
  };
}
