{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (pkgs) callPackage;
in
rec {
  lute = callPackage ./lute.nix { };
  default = lute;
}
