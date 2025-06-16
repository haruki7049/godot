{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/63dacb46bf939521bdc93981b4cbb7ecb58427a0";
    systems.url = "github:nix-systems/default-linux";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    wlroots-flake = {
			url = "git+https://github.com/SimulaVR/wlroots?rev=e44903dee9e2e68219799699c38536e7d9961294&submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
			flake = true;
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
					gdwlroots = pkgs.fetchFromGitHub {
						owner = "SimulaVR";
						repo = "gdwlroots";
						rev = "f5add51f7b5055892177551a341eea510689d19b";
						hash = "sha256-1dIfXA0yWmcX4pZ84bD/Og39tl300YNeiTsWRLV7xh4=";
					};
					wlroots = inputs.wlroots-flake.packages.${system}.default;

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
              pkgs.autoPatchelfHook
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
              pkgs.wayland
              pkgs.pixman
              pkgs.dbus-glib

              libxcb-errors
              wlroots
            ];

            outputs = [
              "out"
              "dev"
            ];

            configurePhase = ''
							echo 'Copying GitHub gdwlroots to ./modules/gdwlroots'
							cp -r ${gdwlroots} modules/gdwlroots
							chmod -R u+w modules/gdwlroots

              echo 'Generating xdg-shell-protocol.{h,c}'
              cd modules/gdwlroots
              ${pkgs.wayland-scanner.bin}/bin/wayland-scanner server-header ${pkgs.wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.h
              ${pkgs.wayland-scanner.bin}/bin/wayland-scanner private-code ${pkgs.wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.c
              cd -
            '';

            buildPhase = ''
              echo Building...
              scons platform=x11 tools=no target=release bits=64 -j $NIX_BUILD_CORES
            '';

            installPhase = ''
              # Install godot
              mkdir -p $out/bin
              cp bin/godot.x11.opt.64 $out/bin/godot

              # Install gdnative headers
              mkdir $dev
              cp -r modules/gdnative/include $dev

              # Install man
              mkdir -p $out/share/man/man6
              cp misc/dist/linux/godot.6 $out/share/man/man6

              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor/scalable/apps
              cp misc/dist/linux/org.godotengine.Godot.desktop $out/share/applications
              cp icon.svg $out/share/icons/hicolor/scalable/apps/godot.svg
              cp icon.png $out/share/icons/godot.png
              substituteInPlace $out/share/applications/org.godotengine.Godot.desktop \
                --replace-warn "Exec=godot" "Exec=$out/bin/godot"
            '';

            meta = {
              homepage = "https://github.com/SimulaVR/godot";
              license = lib.licenses.mit;
              platforms = [ "x86_64-linux" ];
            };
          };
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          packages = {
            inherit godot wlroots;
            default = godot;
          };

          devShells.default = pkgs.mkShell rec {
            nativeBuildInputs = [
              pkgs.nil
              pkgs.just
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
              pkgs.wayland
              pkgs.pixman
              pkgs.dbus-glib

              libxcb-errors
              wlroots
            ];
          };
        };
    };
}
