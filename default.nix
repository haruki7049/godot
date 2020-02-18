{ driverCheck ? "" }:
(import <nixpkgs> {}).callPackage ./godot.nix { driverCheck = driverCheck; }
