{
  lib,
  stdenv,
  fetchgit,
  bun,
  nodejs,
  python3,
  makeWrapper,
  ...
}:

stdenv.mkDerivation rec {
  pname = "_1code";
  version = "unstable";

  src = fetchgit {
    url = "https://github.com/21st-dev/1code.git";
    rev = "HEAD";
    sha256 = lib.fakeSha256;
  };

  nativeBuildInputs = [
    bun
    nodejs
    python3
    makeWrapper
  ];

  # Bun needs a writable home directory for caching
  preBuild = ''
    export HOME=$(mktemp -d)
  '';

  buildPhase = ''
    runHook preBuild

    bun install --frozen-lockfile
    bun run build
    bun run package:${
      if stdenv.isDarwin then "mac"
      else if stdenv.isLinux then "linux"
      else "win"
    }

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    ${if stdenv.isDarwin then ''
      mkdir -p $out/Applications
      cp -r dist/mac*/*.app $out/Applications/
      mkdir -p $out/bin
      makeWrapper "$out/Applications/1Code.app/Contents/MacOS/1Code" $out/bin/1code
    '' else ''
      mkdir -p $out/{bin,lib/1code}
      cp -r dist/linux*/* $out/lib/1code/
      makeWrapper $out/lib/1code/1code $out/bin/1code
    ''}

    runHook postInstall
  '';

  meta = with lib; {
    description = "1Code - AI coding assistant";
    homepage = "https://github.com/21st-dev/1code";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
