{ pkgs }:

let
  common = import ./common.nix { inherit pkgs; };
in

pkgs.mkShell {
  buildInputs =
    with pkgs;
    [
      go
      swww
    ]
    ++ common.buildDeps
    ++ common.libraryDeps;

  shellHook = ''
    echo "Entering development environment for ${common.meta.pname} ${common.meta.version}"
    echo "${common.meta.description}"
  '';
}
