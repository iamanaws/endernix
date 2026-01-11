{
  description = "Manage multiple Minecraft installations with Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    minecraft-metadata.url = "github:Ninlives/minecraft.json";
    minecraft = {
      url = "github:Ninlives/minecraft.nix";
      inputs.metadata.follows = "minecraft-metadata";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      minecraft,
      ...
    }:
    let
      lib = import ./lib {
        inherit (nixpkgs) lib;
        inherit nixpkgs;
      };

      forSystems =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          f {
            pkgs = import nixpkgs { inherit system; };
            minecraftPkgs = minecraft.legacyPackages.${system};
            inherit (lib) mkInstance mkMod modrinth;
          }
        );
    in
    {
      inherit lib minecraft;

      formatter = forSystems ({ pkgs, ... }: pkgs.nixfmt-tree);

      packages = forSystems (
        { pkgs, ... }:
        {
          update-mods = pkgs.writeShellScriptBin "update-mods" ''
            exec ${pkgs.python3}/bin/python3 ${./scripts/update-mods.py} "$@"
          '';
        }
      );
    };
}
