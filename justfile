default:
    @just --list

build:
    scons platform=x11 tools=no target=debug bits=64
