{
  stdenv,
  lib,
  fetchFromGitHub,
  runCommand,
  writableTmpDirAsHomeHook,
  nix-prefetch-git,
  cacert,
  cmake,
  ninja,
  perl,
  git,
  pkg-config,
  tuneHash ? "sha256-DIWy/bkQvIAU6CeM/87qxl9xmgbvv9dCLmtT9cPKFL4=",
}:
let
  baseAttrs = finalAttrs: {
    version = "1.0.1-nightly.20260909";

    src = fetchFromGitHub {
      owner = "luau-lang";
      repo = "lute";
      tag = "v${finalAttrs.version}";
      hash = "sha256-2R50YBCVwdPs2Hi7eljjylTguG43d1nXoqkGxOuwGbk=";
    };

    tune =
      runCommand "lute-${finalAttrs.version}-tune"
        {
          src = "${finalAttrs.src}/extern";
          nativeBuildInputs = [
            nix-prefetch-git
            cacert
          ];
          outputHash = tuneHash;
          outputHashMode = "recursive";
        }
        ''
          mkdir -p "$out"

          for file in "$src"/*.tune; do
            if [[ -f "$file" ]]; then
              echo "fetching $(basename "$file")"

              name=$(grep '^name' "$file" | sed -E 's/^name *= *"(.*)"/\1/')
              remote=$(grep '^remote' "$file" | sed -E 's/^remote *= *"(.*)"/\1/')
              revision=$(grep '^revision' "$file" | sed -E 's/^revision *= *"(.*)"/\1/')

              nix-prefetch-git --builder --url "$remote" --rev "$revision" --out "$out/$name"
            fi
          done
        '';

    preConfigure = ''
      cp -a "$tune"/* extern
      chmod -R +w extern
    '';

    nativeBuildInputs = [
      cmake
      ninja
      perl
      pkg-config
      git
    ];

    cmakeFlags = [
      "-GNinja"
    ]
    # this makes HTTPS work
    ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
      "-DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt"
    ];
    ninjaFlags = [ "lute/cli/lute" ];

    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/bo/boringssl/package.nix#L33
    NIX_CFLAGS_COMPILE = toString (
      lib.optionals stdenv.cc.isGNU [
        # Needed with GCC 12 but breaks on darwin (with clang)
        "-Wno-error=stringop-overflow"
      ]
      ++ lib.optionals stdenv.cc.isClang [
        "-Wno-error=character-conversion"
      ]
    );

    LUTE_VERSION_SUFFIX =
      let
        match = builtins.match ".+-(.+)" finalAttrs.version;
      in
      if match == null then null else builtins.head match;

    installPhase = ''
      mkdir -p $out/bin
      cp lute/cli/lute $out/bin
    '';

    meta = {
      mainProgram = "lute";
    };
  };

  lute0 = stdenv.mkDerivation (
    finalAttrs:
    let
      base = baseAttrs finalAttrs;
    in
    base
    // {
      pname = "lute0";
      cmakeFlags = base.cmakeFlags ++ [ "-DLUTE_STDLESS=ON" ];
    }
  );
in
stdenv.mkDerivation (
  finalAttrs:
  let
    base = baseAttrs finalAttrs;
  in
  base
  // {
    pname = "lute";
    nativeBuildInputs = base.nativeBuildInputs ++ [ lute0 ];

    preConfigure = base.preConfigure + ''
      lute tools/luthier.luau generate lute
    '';
  }
)
