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
          wlroots = pkgs.stdenv.mkDerivation {
            pname = "wlroots";
            version = "0.10.0-simula";

            src = pkgs.fetchFromGitHub {
              owner = "SimulaVR";
              repo = "wlroots";
              rev = "7d065df6f723bbb592fc50150feb213d323f37c6";
              hash = "sha256-1zjTWivMPoWM9tmAoWl5lhKnV1WgCY3wVMANDd9eAqM=";
              fetchSubmodules = true;
            };

            # $out for the library and $examples for the example programs (in examples):
            outputs = [
              "out"
              "examples"
            ];

            nativeBuildInputs = [
              pkgs.meson
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
              pkgs.wayland-scanner.bin
            ];

            buildInputs = [
              pkgs.wayland
              pkgs.libGL
              pkgs.wayland-protocols
              pkgs.libinput
              pkgs.libxkbcommon
              pkgs.pixman
              pkgs.xorg.xcbutilwm
              pkgs.libcap
              pkgs.xorg.xcbutilimage
              pkgs.xorg.xcbutilerrors
              pkgs.mesa
              pkgs.libpng
              pkgs.ffmpeg_4
              pkgs.xorg.libX11.dev
              pkgs.xorg.libxcb.dev
              pkgs.xorg.xinput

              libxcb-errors
            ];

            mesonFlags = [
              "-Dlibcap=enabled"
              "-Dlogind=enabled"
              "-Dxwayland=enabled"
              "-Dx11-backend=enabled"
              "-Dxcb-icccm=disabled"
              "-Dxcb-errors=enabled"
            ];

            LDFLAGS = [
              "-lX11-xcb"
              "-lxcb-xinput"
            ];

            postInstall = ''
              # Copy the library to $examples
              mkdir -p $examples/lib
              cp -Pr libwlroots* $examples/lib/
            '';

            postFixup = ''
              # Install ALL example programs to $examples:
              # screencopy dmabuf-capture input-inhibitor layer-shell idle-inhibit idle
              # screenshot output-layout multi-pointer rotation tablet touch pointer
              # simple
              mkdir -p $examples/bin
              cd ./examples
              for binary in $(find . -executable -type f -printf '%P\n' | grep -vE '\.so'); do
                cp "$binary" "$examples/bin/wlroots-$binary"
              done
            '';

            meta = with lib; {
              description = "More or less a pinned version of wlroots that Simula can use (with a few patches)";
              homepage = "https://github.com/SimulaVR/wlroots";
              license = licenses.mit;
              platforms = platforms.linux;
            };
          };
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
          leap-sdk = pkgs.stdenv.mkDerivation {
            name = "leap-sdk";
            src = pkgs.fetchFromGitHub {
              owner = "SimulaVR";
              repo = "gdleapmotionV2";
              rev = "e3917f9a45ad7899704c65a3120cec38f3e093bb";
              hash = "sha256-F9N4yC/Mw3LcW+LQCCfnRzOYPS8mEypnX7UodnZdY4U=";
            };

            nativeBuildInputs = [
              pkgs.autoPatchelfHook
            ];

            buildInputs = [
              pkgs.stdenv.cc.cc.lib
            ];

            dontBuild = true;

            outputs = [
              "out"
              "dev"
            ];

            installPhase = ''
              mkdir -p $dev/include
              mkdir -p $out/lib

              cp LeapSDK/include/* $dev/include
              cp LeapSDK/lib/x64/* $out/lib
            '';

            meta = {
              homepage = "https://github.com/SimulaVR/gdleapmotionV2";
              license = lib.licenses.unfree;
              platforms = [ "x86_64-linux" ];
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
              leap-sdk
            ];

            outputs = [
              "out"
              "dev"
            ];

            configurePhase = ''
              echo 'Copying libLeap.so from .#leap-sdk'
              cd modules/gdleapmotionV2/LeapSDK/lib/x64/
              cp ${leap-sdk}/lib/* .
              cd -


              echo 'Generate xdg-shell-protocol.{h,c}'
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
            inherit godot wlroots leap-sdk;
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
              pkgs.wayland
              pkgs.pixman
              pkgs.dbus-glib

              libxcb-errors
              wlroots
              leap-sdk
            ];
          };
        };
    };
}
