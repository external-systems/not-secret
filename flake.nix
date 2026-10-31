{
  description = "Public placeholder values for external-systems fleets — same schema and outputs as the private external-systems/secrets";

  inputs = {
    # Shared-input authority for the org: nixpkgs (only its lib is used
    # here) and flake-parts come from the artifact flake, so consumers
    # that already follow it lock nothing new. Named org-pkgs, never
    # pkgs: `pkgs` is the nixpkgs package set everywhere else.
    org-pkgs.url = "github:external-systems/pkgs";
    nixpkgs.follows = "org-pkgs/nixpkgs";
    flake-parts.follows = "org-pkgs/flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        inputs.flake-parts.flakeModules.partitions
        ./flakeModules/values.nix
      ];

      values = {
        dir = ./values;
        placeholder = true;
      };

      # Apps, checks, the formatter and docs are evaluated only on demand;
      # a consumer reading `values` never fetches dev/flake.nix's inputs.
      # The dev shell is devenv (devenv.yaml), not a flake output.
      partitionedAttrs = {
        apps = "dev";
        checks = "dev";
        formatter = "dev";
        # Docs/slides: `nix build .#documentation` (pkgs flakeModules.dev).
        legacyPackages = "dev";
      };

      partitions.dev = {
        module = ./dev/flake-module.nix;
        extraInputsFlake = ./dev;
      };
    };
}
