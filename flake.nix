{
  description = "1Code - AI coding assistant";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        packages = rec {
          _1code = pkgs.callPackage ./default.nix { };
          default = _1code;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.default;
          exePath = "/bin/1code";
        };
      });
}
