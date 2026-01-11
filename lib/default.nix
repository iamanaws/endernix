# Library functions for nix-modpack
{ lib, nixpkgs }:

{
  mkInstance = import ./mkInstance.nix { inherit lib; };
  mkMod = import ./mkMod.nix { inherit lib; };
  modrinth = import ./modrinth.nix { inherit lib nixpkgs; };
}
