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
  tuneHash ? "sha256-8VUi38/2LP9mCyPgFjrXzVN/v2ZzlhlcgeFRtAChMU8=",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lute";
  version = "0.1.0-nightly.20260311";

  nativeBuildInputs = [
    cmake
    ninja
    perl
    pkg-config
    git
  ];

  src = fetchFromGitHub {
    owner = "luau-lang";
    repo = "lute";
    tag = finalAttrs.version;
    hash = "sha256-kiI+H/PMX0rG/KqOkXM2/bBnQG5d5CBSlgS+4iidjh8=";
  };

  tune =
    runCommand "${finalAttrs.finalPackage.name}-tune"
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

  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/bo/boringssl/package.nix#L33
  env.NIX_CFLAGS_COMPILE = toString (
    lib.optionals stdenv.cc.isGNU [
      # Needed with GCC 12 but breaks on darwin (with clang)
      "-Wno-error=stringop-overflow"
    ]
    ++ lib.optionals stdenv.cc.isClang [
      "-Wno-error=character-conversion"
    ]
  );

  cmakeFlags = [
    "-GNinja"
  ]
  # this makes HTTPS work
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "-DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt"
  ];

  preConfigure = ''
    cp -a "$tune"/* extern
    chmod -R +w extern

    mkdir lute/std/src/generated
    cp tools/templates/std_impl.cpp lute/std/src/generated/modules.cpp
    cp tools/templates/std_header.h lute/std/src/generated/modules.h

    mkdir lute/cli/generated
    cp tools/templates/cli_impl.cpp lute/cli/generated/commands.cpp
    cp tools/templates/cli_header.h lute/cli/generated/commands.h

    mkdir lute/batteries/generated
    cp tools/templates/batteries_impl.cpp lute/batteries/generated/batteries.cpp
    cp tools/templates/batteries_header.h lute/batteries/generated/batteries.h

    mkdir lute/definitions/src/generated
    cp tools/templates/definitions_impl.cpp lute/definitions/src/generated/modules.cpp
    cp tools/templates/definitions_header.h lute/definitions/src/generated/modules.h
  '';

  buildPhase = ''
    ninja lute/cli/lute -v \
      && ./lute/cli/lute run "$OLDPWD"/tools/luthier.luau generate lute \
      && ninja lute/cli/lute -v
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp lute/cli/lute $out/bin
  '';

  doCheck = true;
  nativeCheckInputs = [ writableTmpDirAsHomeHook ];
  checkPhase = ''
    ninja tests/lute-tests -v && ( cd "$OLDPWD" && "$OLDPWD"/tests/lute-tests )
  '';

  meta = {
    mainProgram = "lute";
  };
})
