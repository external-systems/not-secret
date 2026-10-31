# The values flake module. not-secrets imports it directly; secrets imports
# it as `inputs.not-secrets.flakeModules.values`. Either way the flake gets
# the same outputs (values, lib, modules.schema, schemaVersion), so
# `--override-input secrets github:external-systems/secrets` is a drop-in
# swap for any consumer.
{
  config,
  lib,
  ...
}: let
  valuesLib = import ../lib {inherit lib;};
  cfg = config.values;
in {
  options.values = {
    dir = lib.mkOption {
      type = lib.types.path;
      description = "Directory of value modules; every .nix file below it is imported.";
    };
    placeholder = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Whether this flake publishes placeholders (not-secrets) or real
        values (secrets). Must agree with the tree's `meta.placeholder`.
      '';
    };
  };

  config.flake = {
    flakeModules = {
      values = ./values.nix;
      checks = ./checks.nix;
    };
    lib = valuesLib;
    modules.schema = valuesLib.schemaModule;
    inherit (valuesLib) schemaVersion;
    values = let
      v = valuesLib.mkValues cfg.dir;
    in
      if v.meta.placeholder == cfg.placeholder
      then v
      else throw "values.placeholder = ${lib.boolToString cfg.placeholder} but ${toString cfg.dir} sets meta.placeholder = ${lib.boolToString v.meta.placeholder}";
  };
}
