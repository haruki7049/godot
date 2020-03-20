(import ../../pinned-nixpkgs.nix {}).callPackage ./godot.nix { devBuild = false; pkgs = (import ../../pinned-nixpkgs.nix); }
