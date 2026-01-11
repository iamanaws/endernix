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
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Library functions for creating Minecraft installations
      lib = import ./lib { inherit (nixpkgs) lib; };

      # Pass through minecraft.nix for convenience
      inherit minecraft;

      # Helper to get everything needed for a system
      # Returns: { pkgs, minecraftPkgs, mkInstance, mkMod }
      forSystem =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          minecraftPkgs = minecraft.legacyPackages.${system};
        in
        {
          inherit pkgs minecraftPkgs;
          inherit (self.lib) mkInstance mkMod;
        };
    };
}
