{
  lib,
  mkShell,
  scons,
  pkg-config,

  # Dependencies
  xorg,
  libGLU,
  zlib,
  alsa-lib,
  libpulseaudio,
  yasm,
  systemd,
}:

mkShell rec {
  nativeBuildInputs = [
    scons
    pkg-config
  ];

  buildInputs = [
    xorg.libX11
    xorg.libXcursor
    xorg.libXinerama
    xorg.libXext
    xorg.libXrandr
    xorg.libXi
    libGLU
    zlib

    alsa-lib
    libpulseaudio
    yasm
    systemd
  ];
}
