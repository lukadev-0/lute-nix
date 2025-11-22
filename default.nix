{
  pkgs ? import <nixpkgs> { },
  lute-src,
}:

let
  inherit (pkgs) callPackage;
in
rec {
  lute = callPackage ./lute.nix {
    inherit lute-src;
  };
  default = lute;
}
