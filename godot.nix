{ stdenv, lib, fetchFromGitHub, scons, pkgconfig, libX11, libXcursor
, libXinerama, libXrandr, libXrender, libpulseaudio ? null
, libXi ? null, libXext, libXfixes, freetype, openssl
, alsaLib, libGLU, zlib, yasm ? null, xwayland, wayland-protocols, libglvnd, libGL, mesa_noglu, pixman, libxkbcommon, x11, eudev, callPackage }:

let
  options = {
    touch = libXi != null;
    pulseaudio = false;
  };
  xvfb-run = callPackage ./xvfb-run.nix { };
  nixGLIntel = ((import ./nixGL.nix) { }).nixGLIntel;
  # nixGLIntel = ((import ./nixGL.nix) { system = builtins.currentSystem; nvidiaVersion = null; nvidiaHash = null; pkgs = pkgs; }).nixGLIntel;
  wlroots = callPackage ../wlroots/wlroots.nix { };

in stdenv.mkDerivation rec {
  pname = "godot";
  version = "3.2";

  src = ./.;

  nativeBuildInputs = [ scons pkgconfig ];

  buildInputs = [
    libX11 libXcursor libXinerama libXrandr libXrender
    libXi libXext libXfixes freetype openssl alsaLib libpulseaudio
    libGLU zlib yasm
    wlroots xwayland wayland-protocols libglvnd libGL mesa_noglu libxkbcommon x11 eudev xvfb-run nixGLIntel
  ];

  patches = [
    ./pkg_config_additions.patch
    ./dont_clobber_environment.patch
  ];

  enableParallelBuilding = true;

  sconsFlags = "target=debug platform=x11";
  preConfigure = ''
    sconsFlags+=" ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${builtins.toJSON v}") options)}"
  '';

  outputs = [ "out" "dev" "man" ];

  configurePhase = ''
    # cp -r gdwlroots-src modules/gdwlroots
    # chmod u+w -R modules/gdwlroots
    # cat modules/gdwlroots/SCsub

    cd modules/gdwlroots
    wayland-scanner server-header ${wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.h
    wayland-scanner private-code ${wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.c
    cd ../..
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    cp bin/godot.* $out/bin/godot

    mkdir "$dev"
    cp -r modules/gdnative/include $dev

    mkdir -p "$man/share/man/man6"
    cp misc/dist/linux/godot.6 "$man/share/man/man6/"

    mkdir -p "$out"/share/{applications,icons/hicolor/scalable/apps}
    cp misc/dist/linux/org.godotengine.Godot.desktop "$out/share/applications/"
    cp icon.svg "$out/share/icons/hicolor/scalable/apps/godot.svg"
    cp icon.png "$out/share/icons/godot.png"
    substituteInPlace "$out/share/applications/org.godotengine.Godot.desktop" \
      --replace "Exec=godot" "Exec=$out/bin/godot"

    nixGLIntel xvfb-run $out/bin/godot --gdnative-generate-json-api $out/bin/api.json
  '';

  meta = {
    homepage    = "https://godotengine.org";
    description = "Free and Open Source 2D and 3D game engine";
    license     = stdenv.lib.licenses.mit;
    platforms   = [ "i686-linux" "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.twey ];
  };
}
