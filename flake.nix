{
  description = "A standalone Luau runtime for general-purpose programming.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
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
        }
      );

      overlays.default = import ./overlay.nix;

      devShells = eachSystem (
        system:
        let
          pkgs = import nixpkgs {
            overlays = [ self.overlays.default ];
            inherit system;
          };

          update-script = pkgs.writeShellScriptBin "update-script" ''
            exec lute ${./update.luau} "$@"
          '';
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.lute
              pkgs.nix-prefetch-git
              update-script
            ];
          };
        }
      );
    };
}
