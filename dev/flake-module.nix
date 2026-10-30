# Dev partition: guard checks, lint and formatter. Shared by not-secrets
# and secrets (`inputs.not-secrets.flakeModules.dev`); a consumer of
# `values` never evaluates it. Which guard runs follows meta.placeholder.
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
    tools = with pkgs; [alejandra statix deadnix];
  in {
    formatter = pkgs.alejandra;

    devShells.default = pkgs.mkShellNoCC {packages = tools;};

    checks =
      {
        lint = pkgs.runCommand "lint" {nativeBuildInputs = tools;} ''
          cd ${self}
          alejandra --check --quiet .
          statix check .
          deadnix --fail .
          touch $out
        '';
        lib-tests = guard "lib-tests" (import ./lib-tests.nix {inherit lib vlib;});
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
