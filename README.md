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
| `flakeModules.checks` | The value guards (`lib-tests`, `placeholders-only`/`no-placeholders`, `shape-parity`) for a dev partition |

## Schema

| Section | Shape |
| --- | --- |
| `meta` | `placeholder` (required), `description` |
| `domains.<name>` | DNS name |
| `networks.<name>` | `ipv4`/`ipv6` each `{cidr, gateway, pools.<name>.{start,end}}`, `nameservers`, `mtu`, `vlan` |
| `hosts.<machine>` | `fqdn`, `targetHost`, `links.<logical>.{interface,mac,network,ipv4,ipv6}`, `addresses.<name>.{address,kind,link}`, `prefixes.<name>.{cidr,kind,link}` |
| `ports.<name>` | port |
| `extra` | untyped escape hatch; promote to a typed section once a kind repeats |

Link addresses are CIDR strings (`"192.0.2.10/24"`), the shape netif's
`static.ipv4`/`static.ipv6` take; `lib.addr` strips the prefix. A link's
`network` must name an entry in `networks`.

A host has any number of links, any number of addresses per link, any
number of named extra addresses (`kind`: additional, floating, failover,
vip, anycast; a bare string is shorthand for `{address = "...";}`), and any
number of named subnets bound to it (`kind`: routed, floating, delegated,
on-link). `link` on an address or prefix must name one of the host's links.

```nix
# An 8-port router: NAT gateway and DNS for two downstream networks.
hosts.router = {
  links = {
    sfp0 = {interface = "enp1s0f0"; network = "uplink"; ipv4 = ["203.0.113.2/30"];};
    sfp1 = {interface = "enp1s0f1"; network = "servers"; ipv4 = ["198.51.100.1/24"];};
    rj0  = {interface = "enp2s0"; mac = "00:00:5e:00:53:10"; network = "home-lan"; ipv4 = ["192.0.2.1/24"];};
    # ... up to sfp3 and rj3
  };
  prefixes.delegated = {cidr = "2001:db8:100::/56"; kind = "delegated"; link = "sfp0";};
};
networks.home-lan = {
  ipv4 = {cidr = "192.0.2.0/24"; gateway = "192.0.2.1"; pools.dhcp = {start = "192.0.2.100"; end = "192.0.2.199";};};
  nameservers = ["192.0.2.1"];
};

# A cloud machine with floating IPs and a routed subnet.
hosts.cloud-1 = {
  links.public = {interface = "eth0"; ipv4 = ["203.0.113.40/32"];};
  addresses = {
    web = {address = "203.0.113.50"; kind = "floating"; link = "public";};
    mail = {address = "2001:db8:5::25"; kind = "floating"; link = "public";};
  };
  prefixes.lb = {cidr = "2001:db8:6::/64"; kind = "routed"; link = "public";};
};
```

Values are plain modules under `values/`, one file per category and one per
host. Every `.nix` file is imported; `_`-prefixed files are skipped.

## Consuming

```nix
# flake.nix
inputs.secrets = {
  url = "github:external-systems/not-secrets";
  inputs.org-pkgs.follows = "org-pkgs"; # if you already follow external-systems/pkgs
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

The repo follows the org flake standard: consumer outputs at the root,
formatter, checks and docs in the `dev` partition (inputs in
`dev/flake.nix`, locked in `dev/flake.lock`), and the devenv CLI shell.
Needs Nix and devenv.

```sh
devenv allow     # auto-activates the shell on cd (after `devenv hook`)
fmt              # nix fmt: treefmt with the org linters
check            # nix flake check: treefmt, lock-sync, guards, docs
docs-build       # static docs to ./result-docs; open index.html from disk
```

After `nix flake update org-pkgs`, run `sync-locks` in the same commit.

Every host, link and network here must also exist in `secrets`
(`checks.shape-parity` there), so add a placeholder first when adding a
machine.
