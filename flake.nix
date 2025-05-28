{
  description = "A Go-based wallpaper selector for swww with Wayland support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    swww = {
      url = "github:LGFae/swww";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      swww,
      ...
    }:
    let
      # Define the overlay once
      swwwOverlay = final: prev: {
        swww = swww.packages.${final.system}.swww;
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend swwwOverlay;
      in
      {
        packages.default = import ./nix/packages.nix { inherit pkgs; };
        devShells.default = import ./nix/shell.nix { inherit pkgs; };
      }
    )
    // {
      overlays.default = swwwOverlay;
      homeManagerModules.default = import ./nix/module.nix { inherit self swww; };
      nixosModules.default =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [
            swwwOverlay
            (final: prev: {
              wallpaper-manager = self.packages.${pkgs.system}.default;
            })
          ];
        };
    };
}
