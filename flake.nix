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
          libxcb-errors = pkgs.stdenv.mkDerivation {
            pname = "libxcb-errors";
            version = "0.0.0";
            src = pkgs.fetchFromGitHub {
              owner = "SimulaVR";
              repo = "libxcb-errors";
              rev = "cb26a7dc442b0bb37f8648986350291d3d45a47a";
              hash = "sha256-LPNRkLQSTPkCRIc9lhHYIvQs8ags3GpGehCWLY5qvJw=";
            };

            nativeBuildInputs = [
              pkgs.pkg-config
              pkgs.python310
              pkgs.autoreconfHook
            ];

            buildInputs = [
              pkgs.xorg.libxcb
              pkgs.xorg.libXau
              pkgs.xorg.libXdmcp
              pkgs.libbsd
              pkgs.xorg.utilmacros
              pkgs.xorg.xcbproto
            ];

            meta = {
              description = "Allow XCB errors to print less opaquely";
              homepage = "https://github.com/SimulaVR/libxcb-errors";
              license = lib.licenses.mit;
              platforms = lib.platforms.linux;
            };
          };
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

              pkgs.libxkbcommon
              pkgs.wlroots
              pkgs.wayland
              pkgs.pixman
              pkgs.dbus-glib

              libxcb-errors
            ];
          };
        };
    };
}
