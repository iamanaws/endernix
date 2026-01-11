# mkInstance - Create isolated Minecraft installations
#
# minecraft.nix uses a single shared game directory by default, making it
# difficult to manage multiple installations with different configurations.
#
# This function creates isolated installations, each with its own:
# - Game directory (~/.local/share/minecraft/<name>)
# - Saves, screenshots, resource packs, etc.
# - Mod configuration (for Fabric)
{ lib }:

{
  pkgs,
  minecraftPkgs,
  name,
  version ? "1_21_1",
  loader ? "fabric", # "vanilla" or "fabric"
  mods ? [ ],
  resourcePacks ? [ ],
  shaderPacks ? [ ],
  jvmArgs ? [ ],
  extraConfig ? { },
}:

let
  inherit (pkgs)
    writeShellScriptBin
    symlinkJoin
    ;

  # Get the base minecraft package for this version/loader
  loaderPkgs = minecraftPkgs."v${version}".${loader}.client;

  # Build the config based on loader type
  baseConfig =
    if loader == "vanilla" then
      { inherit resourcePacks; }
    else
      { inherit mods resourcePacks shaderPacks; };

  # Merge with any extra config
  finalConfig = baseConfig // extraConfig;

  # Create the configured minecraft package
  minecraftBase = loaderPkgs.withConfig [ finalConfig ];

  # JVM args as a string
  jvmArgsStr = lib.concatStringsSep " " jvmArgs;

  # Wrapper script that uses an isolated game directory
  wrapper = writeShellScriptBin "minecraft" ''
    GAME_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/minecraft/${name}"
    mkdir -p "$GAME_DIR"
    cd "$GAME_DIR"

    ${lib.optionalString (jvmArgs != [ ]) ''
      export _JAVA_OPTIONS="${jvmArgsStr} ''${_JAVA_OPTIONS:-}"
    ''}

    exec ${minecraftBase}/bin/minecraft --gameDir "$GAME_DIR" "$@"
  '';

  # Human-readable version string
  versionStr = builtins.replaceStrings [ "_" ] [ "." ] version;
  loaderStr = if loader == "vanilla" then "Vanilla" else "Fabric";
in
symlinkJoin {
  name = "minecraft-${name}";
  paths = [
    wrapper
    minecraftBase
  ];

  postBuild = ''
    rm $out/bin/minecraft
    cp ${wrapper}/bin/minecraft $out/bin/${name}
  '';

  passthru = {
    inherit
      name
      version
      loader
      mods
      resourcePacks
      shaderPacks
      ;
    unwrapped = minecraftBase;

    # Allow further customization
    withMods =
      extraMods:
      pkgs.callPackage ./mkInstance.nix { inherit lib; } {
        inherit
          pkgs
          minecraftPkgs
          name
          version
          loader
          resourcePacks
          shaderPacks
          jvmArgs
          extraConfig
          ;
        mods = mods ++ extraMods;
      };

    withResourcePacks =
      extraPacks:
      pkgs.callPackage ./mkInstance.nix { inherit lib; } {
        inherit
          pkgs
          minecraftPkgs
          name
          version
          loader
          mods
          shaderPacks
          jvmArgs
          extraConfig
          ;
        resourcePacks = resourcePacks ++ extraPacks;
      };
  };

  meta = {
    description = "Minecraft ${loaderStr} ${versionStr} - ${name}";
    mainProgram = name;
    platforms = lib.platforms.linux;
  };
}

