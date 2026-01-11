# Modrinth helpers - declare mods by slug/version
#
# Returns mod specs that mkInstance converts to fetchurl derivations.
# This allows modrinth functions to work without needing pkgs/system.
{ lib, nixpkgs }:

{
  # Load mods from a generated lockfile
  # Returns: [ { __modrinth = true; name; url; hash; ... } ... ]
  fromLockFile =
    lockFile:
    let
      lock = import lockFile;
    in
    builtins.attrValues (
      builtins.mapAttrs (name: entry: {
        __modrinth = true; # marker for mkInstance
        name = entry.filename;
        url = entry.url;
        hash = entry.hash;
        pname = name;
        version = entry.version;
        projectId = entry.projectId;
        versionId = entry.versionId;
      }) lock
    );
}
