# mkMod - Helper for defining mods with metadata
#
# Creates a fetchurl derivation with additional metadata.
# This is optional - plain fetchurl works fine for most cases.
{ lib }:

{
  pkgs,
  pname,
  version,
  url,
  hash,
  # Optional metadata
  description ? "",
  homepage ? "",
  mcVersions ? [ ],
  dependencies ? [ ],
  optional ? [ ],
}:

let
  # Ensure filename has .jar extension (required by Fabric)
  filename = "${pname}.jar";

  mod = pkgs.fetchurl {
    name = filename;
    inherit url hash;

    passthru = {
      inherit
        pname
        version
        description
        homepage
        mcVersions
        dependencies
        optional
        ;
    };

    meta = {
      inherit description homepage;
    };
  };
in
mod
