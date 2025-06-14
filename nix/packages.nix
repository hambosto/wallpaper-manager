{ pkgs }:

let
  common = import ./common.nix { inherit pkgs; };
in

pkgs.buildGoModule {
  pname = common.meta.pname;
  version = common.meta.version;

  src = ./../.;
  vendorHash = "sha256-taM+1aqJ5ax21+aow+i5AQSy7GY+uYCncvVHlYiD8xg=";

  nativeBuildInputs = common.buildDeps ++ [
    pkgs.makeWrapper
  ];
  buildInputs = common.libraryDeps;

  postFixup = ''
    wrapProgram $out/bin/${common.meta.pname} \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.swww
          # pkgs.wallust
        ]
      }
  '';

  postInstall = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/128x128/apps
        
    cp ${../assets/wallpaper-selector.png} $out/share/icons/hicolor/128x128/apps/${common.meta.pname}.png
        
    cat > $out/share/applications/${common.meta.pname}.desktop << EOF
    [Desktop Entry]
    Type=Application
    Name=Wallpaper Manager
    Exec=$out/bin/${common.meta.pname}
    Icon=${common.meta.pname}
    Comment=${common.meta.description}
    Categories=Utility;Graphics;
    EOF
  '';

  meta = with pkgs.lib; {
    description = common.meta.description;
    homepage = common.meta.homepage;
    license = common.meta.license;
    maintainers = common.meta.maintainers;
    platforms = platforms.linux;
  };
}
