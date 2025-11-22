{
  description = "A standalone Luau runtime for general-purpose programming.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";

    lute-src.url = "github:luau-lang/lute";
    lute-src.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      lute-src,
    }:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs (import systems);
    in
    {
      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      packages = eachSystem (
        system:
        import self {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit lute-src;
        }
      );
    };
}
