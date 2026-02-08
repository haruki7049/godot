default:
    @just --list

build:
    wayland-scanner server-header ./modules/gdwlroots/xdg-shell.xml ./modules/gdwlroots/xdg-shell-protocol.h
    wayland-scanner private-code ./modules/gdwlroots/xdg-shell.xml ./modules/gdwlroots/xdg-shell-protocol.c
    scons -Q -j8 platform=x11 target=debug warnings=no x11_egl=yes

build-watch:
    while inotifywait -qqre modify .; do just build; done

clean:
    rm -f ./modules/gdwlroots/xdg-shell-protocol.c
    rm -f ./modules/gdwlroots/xdg-shell-protocol.h
    scons -c
