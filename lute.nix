{
  stdenv,
  lib,
  runCommand,
  cmake,
  ninja,
  perl,
  git,
  pkg-config,
  lute-src,
}:

let
  versionDrv =
    runCommand "lute-version"
      {
        nativeBuildInputs = [ cmake ];
      }
      ''
        cmake -P ${lute-src}/CMakeBuild/get_version.cmake 2> $out
      '';

  filterRegularFiles = lib.filterAttrs (name: type: type == "regular");
  tuneFiles = lib.attrNames (filterRegularFiles (builtins.readDir "${lute-src}/extern"));
  tunes = lib.map (file: lib.importTOML "${lute-src}/extern/${file}") tuneFiles;
in
stdenv.mkDerivation {
  pname = "lute";
  version = lib.trim (lib.readFile versionDrv);

  src = lute-src;
  nativeBuildInputs = [
    cmake
    ninja
    perl
    pkg-config
    git
  ];

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

  cmakeFlags = [ "-GNinja" ];

  preConfigure = ''
    ${lib.concatStrings (
      lib.map (
        tune:
        let
          inherit (tune) dependency;
          repo = builtins.fetchGit {
            name = "tune-${dependency.name}";
            url = dependency.remote;
            rev = dependency.revision;
            shallow = true;
          };
          dest = "extern/${dependency.name}";
        in
        ''
          echo "${repo} -> ${dest}"
          cp -r ${repo} ${dest}
          chmod -R +w ${dest}
        ''
      ) tunes
    )}

    mkdir lute/std/src/generated
    cp tools/templates/std_impl.cpp lute/std/src/generated/modules.cpp
    cp tools/templates/std_header.h lute/std/src/generated/modules.h

    mkdir lute/cli/generated
    cp tools/templates/cli_impl.cpp lute/cli/generated/commands.cpp
    cp tools/templates/cli_header.h lute/cli/generated/commands.h
  '';

  buildPhase = ''
    ninja lute/cli/lute -v \
      && ./lute/cli/lute run $OLDPWD/tools/luthier.luau generate lute \
      && ninja lute/cli/lute -v
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp lute/cli/lute $out/bin
  '';

  doCheck = true;
  checkPhase = ''
    ninja tests/lute-tests -v && HOME=$TMPDIR ./tests/lute-tests
  '';

  meta = {
    mainProgram = "lute";
  };
}
