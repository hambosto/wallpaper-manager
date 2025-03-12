{
  description = "A Go-based wallpaper selector for swww with Wayland support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    swww.url = "github:LGFae/swww";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      swww,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              swww = swww.packages.${system}.swww;
            })
          ];
        };
      in
      {
        packages.default = import ./nix/packages.nix { inherit pkgs; };
        devShells.default = import ./nix/shell.nix { inherit pkgs; };
      }
    )
    // {
      nixosModules.default = import ./nix/module.nix { inherit self; };
    };
}
