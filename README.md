# not-secrets

Public placeholder values for External Systems fleets. This flake owns the
schema; [`external-systems/secrets`](https://github.com/external-systems/secrets)
(private) imports it and supplies the real values. Both expose the same
outputs, so a consumer pins this repo and swaps in the private one at
deploy time.

Placeholders use documentation ranges only: IPv4 from RFC 5737
(`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`), IPv6 from RFC 3849
(`2001:db8::/32`), MACs from RFC 7042 (`00:00:5e:00:53:xx`), and names
under RFC 2606 (`example.com`, `.test`). `checks.placeholders-only` fails if
anything else lands here.

Everything here ends up in the world-readable `/nix/store` of a deployed
machine. Credentials (keys, tokens, passwords) belong in clan vars, never
in either repo.

## Outputs

| Output | What |
| --- | --- |
| `values` | The evaluated, type-checked attrset consumers read |
| `lib` | `addr`, `prefix`, `mkValues`, `shapeOf`, and the guard asserts |
| `schemaVersion` | Bumped on breaking shape changes |
| `modules.schema` | The schema as a plain module |
| `flakeModules.values` | Turns a `values/` directory into the outputs above |
| `flakeModules.dev` | Checks, formatter and devShell (dev partition) |

## Schema

| Section | Shape |
| --- | --- |
| `meta` | `placeholder` (required), `description` |
| `domains.<name>` | DNS name |
| `networks.<name>` | `ipv4.{cidr,gateway}`, `ipv6.{cidr,gateway}`, `nameservers`, `mtu`, `vlan` |
| `hosts.<machine>` | `fqdn`, `targetHost`, `links.<logical>.{interface,mac,network,ipv4,ipv6}`, `addresses.<name>` |
| `ports.<name>` | port |
| `extra` | untyped escape hatch; promote to a typed section once a kind repeats |

Link addresses are CIDR strings (`"192.0.2.10/24"`), the shape netif's
`static.ipv4`/`static.ipv6` take; `lib.addr` strips the prefix. A link's
`network` must name an entry in `networks`.

Values are plain modules under `values/`, one file per category and one per
host. Every `.nix` file is imported; `_`-prefixed files are skipped.

## Consuming

```nix
# flake.nix
inputs.secrets = {
  url = "github:external-systems/not-secrets";
  inputs.pkgs.follows = "pkgs"; # if you already follow external-systems/pkgs
};

# clan inventory / machine modules, with secrets = inputs.secrets.values
{secrets, ...}: let
  inherit (secrets.hosts.nixos.links) lan;
in {
  instances.home-lan = {
    module = {
      input = "clanServices";
      name = "netif";
    };
    roles.default = {
      settings.gateway.ipv4 = secrets.networks.home-lan.ipv4.gateway;
      machines.nixos.settings.links.lan = {
        inherit (lan) interface;
        static = {
          inherit (lan) ipv4 ipv6;
        };
      };
    };
  };
}
```

Deploy with the real values, never committing the override:

```sh
clan machines update nixos --flake . -- --override-input secrets github:external-systems/secrets
```

A deploy script should also call
`inputs.secrets.lib.assertNoPlaceholders inputs.secrets.values` (or check
`values.meta.placeholder`) so placeholders can never reach a machine.

## Development

```sh
nix fmt .
nix flake check
```

Every host, link and network here must also exist in `secrets`
(`checks.shape-parity` there), so add a placeholder first when adding a
machine.
