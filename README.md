# lute-nix

The [Lute][lute] runtime for Luau, packaged for Nix.

```sh
nix run github:lukadev-0/lute-nix
```

[lute]: https://github.com/luau-lang/lute

## Flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    lute.url = "github:lukadev-0/lute-nix";
    lute.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      lute,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [ lute.packages.${system}.lute ];
      };
    };
}
```

You can override the `lute-src` input to use a specific Lute commit.

```nix
{
  inputs = {
    lute.inputs.lute-src.url = "github:luau-lang/lute/26b8e251acd9f6009c64ae982f04471ee6d9a5af";
  };
}
```

## Non-Flake

```nix
let
  # It is recommended to pin these to a specific commit instead of using a branch.
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable";
  lute-src = fetchTarball "https://github.com/luau-lang/lute/tarball/primary";
  lute-nix = fetchTarball "https://github.com/lukadev-0/lute-nix/tarball/main";

  pkgs = import nixpkgs { };
  lute = import lute-nix {
    inherit pkgs lute-src;
  };
in
pkgs.mkShellNoCC {
  packages = [ lute.lute ];
}
```
