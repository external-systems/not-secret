# Dev partition: the org base (treefmt, lock-sync, docs) from pkgs and
# the value guards. A consumer of `values` never evaluates it.
{inputs, ...}: {
  imports = [
    inputs.org-pkgs.flakeModules.dev
    ../documentation/flake-module.nix
    ../flakeModules/checks.nix
  ];
}
