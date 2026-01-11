# Library functions for nix-modpack
{ lib }:

{
  mkInstance = import ./mkInstance.nix { inherit lib; };
  mkMod = import ./mkMod.nix { inherit lib; };
}
