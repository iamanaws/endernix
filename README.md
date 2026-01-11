# nix-modpack

Manage multiple Minecraft installations with Nix, built on [minecraft.nix](https://github.com/Ninlives/minecraft.nix).

## Why?

minecraft.nix is great for running Minecraft declaratively, but it uses a single shared game directory. This makes it difficult to run multiple installations side by side - different mod configurations, different versions, or separate worlds.

nix-modpack solves this by giving each installation its own isolated game directory with its own saves, screenshots, and configuration.

## Usage

### Basic Example

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-modpack.url = "github:iamanaws/nix-modpack";
  };

  outputs = { self, nixpkgs, nix-modpack, ... }:
    let
      system = "x86_64-linux";
      inherit (nix-modpack.forSystem system) pkgs minecraftPkgs mkInstance;
    in {
      packages.${system}.my-instance = mkInstance {
        inherit pkgs minecraftPkgs;
        name = "my-instance";
        version = "1_21_1";
        loader = "fabric";

        mods = [
          (pkgs.fetchurl {
            name = "fabric-api.jar";
            url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/m6zu1K31/fabric-api-0.116.7+1.21.1.jar";
            hash = "sha256-CAGMxIyXQVo4AWoA29Wix6Rgumt6BRaQqMs9u16EgqQ=";
          })
        ];
      };
    };
}
```

### Organizing Mods

For larger installations, define your mods in a separate file:

```nix
# mods.nix
{ pkgs }:
let
  inherit (pkgs) fetchurl;
in {
  fabric-api = fetchurl {
    name = "fabric-api.jar";
    url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/m6zu1K31/fabric-api-0.116.7+1.21.1.jar";
    hash = "sha256-CAGMxIyXQVo4AWoA29Wix6Rgumt6BRaQqMs9u16EgqQ=";
  };

  jei = fetchurl {
    name = "jei-fabric.jar";
    url = "https://cdn.modrinth.com/data/u6dRKJwZ/versions/TvqzuFwN/jei-1.21.1-fabric-19.27.0.340.jar";
    hash = "sha256-gMNb6eQvynHspXflODNpAlR8H+P1re2yt5VGqwH2a78=";
  };
}
```

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-modpack.url = "github:iamanaws/nix-modpack";
  };

  outputs = { self, nixpkgs, nix-modpack, ... }:
    let
      system = "x86_64-linux";
      inherit (nix-modpack.forSystem system) pkgs minecraftPkgs mkInstance;
      mods = import ./mods.nix { inherit pkgs; };
    in {
      packages.${system}.my-instance = mkInstance {
        inherit pkgs minecraftPkgs;
        name = "my-instance";
        loader = "fabric";
        mods = with mods; [ fabric-api jei ];
      };
    };
}
```

### Multiple Installations

```nix
{
  packages.${system} = {
    # Modded installation with Cobblemon
    cobblemon = mkInstance {
      inherit pkgs minecraftPkgs;
      name = "cobblemon";
      loader = "fabric";
      mods = with mods; [ fabric-api cobblemon /* ... */ ];
    };

    # Light modded installation with QoL mods
    vanilla-plus = mkInstance {
      inherit pkgs minecraftPkgs;
      name = "vanilla-plus";
      loader = "fabric";
      mods = with mods; [ fabric-api jei ];
    };

    # Pure vanilla - isolated directory, no mods
    vanilla = mkInstance {
      inherit pkgs minecraftPkgs;
      name = "vanilla";
      loader = "vanilla";
    };
  };
}
```

Each installation gets its own command: `cobblemon`, `vanilla-plus`, `vanilla`.

## API Reference

### `mkInstance`

Creates an isolated Minecraft installation.

```nix
mkInstance {
  pkgs;                   # nixpkgs
  minecraftPkgs;          # minecraft.nix legacyPackages
  name;                   # installation name (used for binary and game dir)
  version ? "1_21_1";     # minecraft version (use underscores)
  loader ? "fabric";      # "vanilla" or "fabric"
  mods ? [];              # list of mod .jar files (fabric only)
  resourcePacks ? [];     # list of resource pack files
  shaderPacks ? [];       # list of shader pack files (fabric only)
  jvmArgs ? [];           # extra JVM arguments
  extraConfig ? {};       # extra config passed to minecraft.nix
}
```

**Returns:** A derivation with:
- `bin/<name>` - launcher script
- `passthru.withMods` - function to add more mods
- `passthru.withResourcePacks` - function to add more resource packs
- `passthru.unwrapped` - the underlying minecraft.nix package

### `mkMod` (optional)

Helper for defining mods with metadata. Plain `fetchurl` works fine for most cases.

```nix
mkMod {
  pkgs;
  pname;          # mod name
  version;        # mod version
  url;            # download URL
  hash;           # sri hash

  # Optional metadata
  description ? "";
  homepage ? "";
  mcVersions ? [];
  dependencies ? [];
  optional ? [];
}
```

## Game Data Location

Each installation stores its data in `~/.local/share/minecraft/<name>/`:

```
~/.local/share/minecraft/
├── cobblemon/
│   ├── saves/
│   ├── resourcepacks/
│   ├── screenshots/
│   └── ...
├── vanilla-plus/
│   └── ...
└── vanilla/
    └── ...
```

## Adding Mods

1. Find the mod on [Modrinth](https://modrinth.com/) or [CurseForge](https://www.curseforge.com/minecraft/mc-mods)
2. Get the direct download URL for the `.jar` file
3. Add it with `fetchurl`:

```nix
my-mod = pkgs.fetchurl {
  name = "my-mod.jar";  # Must end in .jar for Fabric to load it
  url = "https://cdn.modrinth.com/data/.../my-mod-1.0.jar";
  hash = "";  # Leave empty, nix will error with the correct hash
};
```

## License

MIT
