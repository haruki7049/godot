{ onNixOS ? false, devBuild ? true }: 
(import ../../pinned-nixpkgs.nix {}).callPackage ./godot.nix { onNixOS = onNixOS; devBuild = devBuild; pkgs = (import ../../pinned-nixpkgs.nix); }
