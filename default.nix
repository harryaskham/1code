{
  lib,
  stdenv,
  fetchzip,
  fetchurl,
  bun,
  nodejs_20,
  python311,
  makeWrapper,
  # Native dependencies for better-sqlite3 and node-pty
  pkg-config,
  libuv,
  # Darwin-specific
  xcbuild,
  apple-sdk_15,
  cctools,
  # Build tools
  gnumake,
  gnused,
  electron,
  ...
}:

let
  nodejs = nodejs_20;
  # Python with setuptools for node-gyp (distutils was removed in Python 3.12+)
  python = python311.withPackages (ps: [ ps.setuptools ]);
  # Determine architecture for native module builds
  nodeArch = if stdenv.isAarch64 then "arm64" else "x64";
  packageStr = if stdenv.isDarwin then "mac" else if stdenv.isLinux then "linux" else "win";

  # Upstream uses Electron 33.4.5 (ABI 130), so we need matching headers
  electronVersion = "33.4.5";
  electronHeaders = fetchurl {
    url = "https://electronjs.org/headers/v${electronVersion}/node-v${electronVersion}-headers.tar.gz";
    hash = "sha256-Af+M0mf1vvnvzZ3MNqcs7acDAsGV6PEN+RnZo1FVFPI=";
  };
in
stdenv.mkDerivation rec {
  pname = "1code";
  version = "0.0.23";

  src = fetchzip {
    url = "https://github.com/21st-dev/1code/archive/refs/tags/v${version}.zip";
    hash = "sha256-oHlzRD40hSt1AJTeyapYtNvvzbPkq3gSTq0SkVMdlj8=";
  };

  nativeBuildInputs = [
    bun
    nodejs
    python
    makeWrapper
    pkg-config
    gnumake
    gnused  # lzma-native requires GNU sed
    electron
  ] ++ lib.optionals stdenv.isDarwin [
    xcbuild  # Provides xcodebuild
    cctools  # Provides Darwin libtool (not GNU libtool)
  ];

  buildInputs = [
    libuv
  ] ++ lib.optionals stdenv.isDarwin [
    apple-sdk_15
  ];

  # Tell node-gyp to use make instead of xcodebuild where possible
  GYP_DEFINES = "mac_deployment_target=10.15";

  # Disable patchelf on Darwin (it's Linux-only)
  dontPatchELF = stdenv.isDarwin;
  dontStrip = stdenv.isDarwin;

  # Bun/npm needs writable directories
  preBuild = ''
    export HOME=$(mktemp -d)
  '';

  buildPhase = ''
    runHook preBuild

    export ELECTRON_SKIP_BINARY_DOWNLOAD=1

    # Extract Electron 33 headers (matching upstream's electron version)
    mkdir -p $HOME/electron-headers
    tar -xzf ${electronHeaders} -C $HOME/electron-headers --strip-components=1

    # Configure node-gyp to build against Electron 33's Node ABI (130), not system Node
    export npm_config_nodedir=$HOME/electron-headers
    export npm_config_target=${electronVersion}
    export npm_config_arch=${nodeArch}
    export npm_config_target_arch=${nodeArch}
    export npm_config_disturl=https://electronjs.org/headers
    export npm_config_runtime=electron

    bun install

    ${nodejs}/bin/npx electron-rebuild -p -f -w better-sqlite3 \
      -m . \
      -a ${nodeArch} \
      -d $HOME/electron-headers \
      -v ${electronVersion}

    # Verify the native module was built for correct ABI
    file node_modules/better-sqlite3/build/Release/better_sqlite3.node || true

    bun run build
    bun run package:${packageStr} || true

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    ${if stdenv.isDarwin then ''
      # Install the .app bundle
      mkdir -p $out/Applications
      cp -r release/mac-arm64/1Code.app $out/Applications/

      # Create bin symlink for CLI access
      mkdir -p $out/bin
      makeWrapper "$out/Applications/1Code.app/Contents/MacOS/1Code" $out/bin/1code
    '' else ''
      mkdir -p $out/bin
      cp -r release/linux/1code $out/bin/1code
    ''}

    runHook postInstall
  '';

  meta = with lib; {
    description = "1Code - AI coding assistant";
    homepage = "https://github.com/21st-dev/1code";
    license = licenses.unfree;
    mainProgram = "1code";
    platforms = platforms.unix;
  };
}
