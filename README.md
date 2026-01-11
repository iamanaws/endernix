# nix-modpack

Manage multiple Minecraft installations with Nix, built on [minecraft.nix](https://github.com/Ninlives/minecraft.nix).

## Why?

minecraft.nix is great for running Minecraft declaratively, but it uses a single shared game directory. This makes it difficult to run multiple installations side by side - different mod configurations, different versions, or separate worlds.

nix-modpack solves this by giving each installation its own isolated game directory with its own saves, screenshots, and configuration.

## Usage

### Using Modrinth (Recommended)

Declare mods by slug and version, let the tooling resolve URLs and hashes from the [Modrinth API](https://docs.modrinth.com/api/).

**1. Create your mod declarations (`mods.nix`):**

```nix
{
  # String: specific version
  fabric-api = "0.116.7+1.21.1";

  # Attribute set: specific version
  fabric-language-kotlin = {
    version = "1.13.8+kotlin.2.3.0";
    gameVersion = "1.21.1";
  };

  # Attribute set: latest compatible
  jei = {
    gameVersion = "1.21.1";
  };
}
```

**2. Generate the lockfile:**

```bash
nix run github:iamanaws/nix-modpack#update-mods -- mods.nix
```

This creates `mods.lock.nix` with resolved URLs and hashes.

**3. Use in your flake:**

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-modpack.url = "github:iamanaws/nix-modpack";
  };

  outputs = { self, nixpkgs, nix-modpack, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      minecraftPkgs = nix-modpack.minecraft.legacyPackages.${system};
      inherit (nix-modpack.lib) mkInstance modrinth;
    in {
      packages.${system}.my-instance = mkInstance {
        inherit pkgs minecraftPkgs;
        name = "my-instance";
        loader = "fabric";
        mods = modrinth.fromLockFile { lockFile = ./mods.lock.nix; };
      };
    };
}
```

### Mod Declaration Format

| Field | Description |
|-------|-------------|
| `project` | Modrinth project slug (defaults to the attribute name) |
| `version` | Version number (omit to get latest compatible) |
| `gameVersion` | Minecraft version: `"1.21.1"` |
| `loader` | Mod loader (defaults to `"fabric"`) |

### Manual Mods (fetchurl)

For mods not on Modrinth:

```nix
mkInstance {
  inherit pkgs minecraftPkgs;
  name = "my-instance";
  loader = "fabric";
  mods = [
    (pkgs.fetchurl {
      name = "fabric-api.jar";
      url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/m6zu1K31/fabric-api-0.116.7+1.21.1.jar";
      hash = "sha256-CAGMxIyXQVo4AWoA29Wix6Rgumt6BRaQqMs9u16EgqQ=";
    })
  ];
}
```

### Mixing Modrinth and Manual Mods

```nix
let
  # Mods from Modrinth lockfile
  modrinthMods = modrinth.fromLockFile { lockFile = ./mods.lock.nix; };

  # Manual mods (CurseForge, direct downloads, etc.)
  manualMods = [
    (pkgs.fetchurl {
      name = "some-mod.jar";
      url = "https://example.com/some-mod-1.0.jar";
      hash = "sha256-...";
    })
  ];
in
mkInstance {
  inherit pkgs minecraftPkgs;
  name = "mixed";
  loader = "fabric";
  mods = modrinthMods ++ manualMods;
}
```

### Multiple Installations

```nix
{
  packages.${system} = {
    modded = mkInstance {
      inherit pkgs minecraftPkgs;
      name = "modded";
      loader = "fabric";
      mods = modrinth.fromLockFile { lockFile = ./mods.lock.nix; };
    };

    vanilla = mkInstance {
      inherit pkgs minecraftPkgs;
      name = "vanilla";
      loader = "vanilla";
    };
  };
}
```

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

### `modrinth.fromLockFile`

Load mods from a generated lockfile.

```nix
modrinth.fromLockFile { lockFile = ./mods.lock.nix; }
# Returns: [ <derivation> ... ]
```

# Returns: [ <derivation> ... ]
```

## CLI Tools

### `update-mods`

Resolve mods from [Modrinth API](https://docs.modrinth.com/api/) and generate a lockfile.

```bash
# Run from nix-modpack
nix run github:iamanaws/nix-modpack#update-mods -- mods.nix

# Or expose it in your flake for convenience
nix run .#update-mods -- mods.nix
```

To expose in your flake:

```nix
{
  inherit (nix-modpack.packages.${system}) update-mods;
}
```

## Game Data Location

Each installation stores its data in `~/.local/share/minecraft/<name>/`:

```
~/.local/share/minecraft/
├── modded/
│   ├── saves/
│   ├── resourcepacks/
│   └── ...
└── vanilla/
    └── ...
```
