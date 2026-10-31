# Value guard checks. Imported by the dev partition of not-secrets and of
# secrets (`inputs.not-secrets.flakeModules.checks`); a consumer of
# `values` never evaluates it. Which guard runs follows meta.placeholder.
# Formatting and lint: checks.treefmt (pkgs flakeModules.dev).
{
  inputs,
  lib,
  self,
  ...
}: let
  vlib = self.lib;
  inherit (self.values.meta) placeholder;
  # secrets declares not-secrets as an input: its values are the shape
  # reference. not-secrets has no such input and skips the parity check.
  reference = inputs.not-secrets.values or null;
in {
  perSystem = {pkgs, ...}: let
    # Fails the check derivation at eval time with the guard's message.
    guard = name: ok:
      pkgs.runCommand name {} ''
        echo ${lib.boolToString ok} > $out
      '';
  in {
    checks =
      {
        lib-tests = guard "lib-tests" (import ../lib/tests.nix {inherit lib vlib;});
      }
      // (
        if placeholder
        then {placeholders-only = guard "placeholders-only" (vlib.assertPlaceholdersOnly self.values);}
        else {no-placeholders = guard "no-placeholders" (vlib.assertNoPlaceholders self.values);}
      )
      // lib.optionalAttrs (reference != null) {
        shape-parity = guard "shape-parity" (vlib.assertSameShape reference self.values);
      };
  };
}
