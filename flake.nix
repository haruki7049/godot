{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/63dacb46bf939521bdc93981b4cbb7ecb58427a0";
    systems.url = "github:nix-systems/default-linux";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        let
          godot = pkgs.stdenv.mkDerivation {
            pname = "godot";
            version = "3.x-simula";
            src = lib.cleanSource ./.;

            nativeBuildInputs = [
              pkgs.scons
              pkgs.pkg-config
            ];

            buildInputs = [
              pkgs.xorg.libX11
              pkgs.xorg.libXcursor
              pkgs.xorg.libXinerama
              pkgs.xorg.libXext
              pkgs.xorg.libXrandr
              pkgs.xorg.libXi
              pkgs.libGLU
              pkgs.zlib

              pkgs.alsa-lib
              pkgs.libpulseaudio
              pkgs.yasm
              pkgs.systemd
            ];

            buildPhase = ''
              echo Building...
              scons
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp bin/godot.x11.tools.64 $out/bin/godot
            '';
          };
        in
        {
          packages = {
            inherit godot;
            default = godot;
          };

          devShells.default = pkgs.mkShell rec {
            nativeBuildInputs = [
              pkgs.scons
              pkgs.pkg-config
            ];

            buildInputs = [
              pkgs.xorg.libX11
              pkgs.xorg.libXcursor
              pkgs.xorg.libXinerama
              pkgs.xorg.libXext
              pkgs.xorg.libXrandr
              pkgs.xorg.libXi
              pkgs.libGLU
              pkgs.zlib

              pkgs.alsa-lib
              pkgs.libpulseaudio
              pkgs.yasm
              pkgs.systemd
            ];
          };
        };
    };
}
