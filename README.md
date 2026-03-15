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

### Overlay

The flake provides an overlay that adds the `lute` attribute.

```nix
let
  system = "x86_64-linux";
  pkgs = import nixpkgs {
    overlays = [ lute.overlays.default ];
    inherit system;
  };
in
{
  devShells.${system}.default = pkgs.mkShellNoCC {
    packages = [ pkgs.lute ];
  };
};
```

## Non-Flake

```nix
let
  # It is recommended to pin these to a specific commit instead of using a branch.
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable";
  lute-nix = fetchTarball "https://github.com/lukadev-0/lute-nix/tarball/main";

  pkgs = import nixpkgs { };
  lute = import lute-nix { inherit pkgs; };
in
pkgs.mkShellNoCC {
  packages = [ lute.lute ];
}
```

### Overlay

An overlay is available at `overlay.nix` that adds the `lute` attribute.

```nix
let
  # It is recommended to pin these to a specific commit instead of using a branch.
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable";
  lute-nix = fetchTarball "https://github.com/lukadev-0/lute-nix/tarball/main";

  pkgs = import nixpkgs {
    overlays = [ (import "${lute-nix}/overlay.nix") ];
  };
in
pkgs.mkShellNoCC {
  packages = [ pkgs.lute ];
}
```

## Binary cache

[Garnix][garnix] is used for CI. Build outputs are made available in [Garnix's cache][garnix-cache] (`cache.garnix.io`).

[garnix]: https://garnix.io/
[garnix-cache]: https://garnix.io/docs/ci/caching/
