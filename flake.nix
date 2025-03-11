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
      nixosModules.default = import ./nix/module.nix { inherit self; };
    };
}
