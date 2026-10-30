{
  description = "Public placeholder values for external-systems fleets — same schema and outputs as the private external-systems/secrets";

  inputs = {
    # Shared-input authority for the org: nixpkgs (only its lib is used
    # here) and flake-parts come from the artifact flake, so consumers
    # that already follow pkgs lock nothing new.
    pkgs.url = "github:external-systems/pkgs";
    nixpkgs.follows = "pkgs/nixpkgs";
    flake-parts.follows = "pkgs/flake-parts";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        inputs.flake-parts.flakeModules.partitions
        ./flake-module.nix
      ];

      values = {
        dir = ./values;
        placeholder = true;
      };

      # Checks, formatter and devShell are evaluated only on demand; a
      # consumer reading `values` never touches them.
      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        formatter = "dev";
      };

      partitions.dev.module = ./dev/flake-module.nix;
    };
}
