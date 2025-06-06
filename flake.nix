{
  description = "A Go-based wallpaper selector for swww with Wayland support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = import ./nix/packages.nix { inherit pkgs; };
        devShells.default = import ./nix/shell.nix { inherit pkgs; };
      }
    )
    // {
      homeManagerModules.default = import ./nix/module.nix { inherit self; };
      nixosModules.default =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [
            (final: prev: {
              wallpaper-manager = self.packages.${pkgs.system}.default;
            })
          ];
        };
    };
}
