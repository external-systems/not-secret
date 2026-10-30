# The single schema shared by external-systems/not-secrets (placeholders)
# and external-systems/secrets (real values). Facts only: no consumer
# (clanServices netif, NixOS networking) shape leaks in here, so the data
# outlives any change to how networking is rendered.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  t = import ./types.nix {inherit lib;};

  addressFamily = family: cidrType: ipType:
    types.submodule {
      options = {
        cidr = mkOption {
          type = types.nullOr cidrType;
          default = null;
          description = "The ${family} network prefix, e.g. the LAN subnet.";
        };
        gateway = mkOption {
          type = types.nullOr ipType;
          default = null;
          description = "The ${family} default gateway on this network.";
        };
      };
    };

  network = types.submodule {
    options = {
      ipv4 = mkOption {
        type = addressFamily "IPv4" t.cidr4 t.ipv4;
        default = {};
        description = "IPv4 prefix and gateway.";
      };
      ipv6 = mkOption {
        type = addressFamily "IPv6" t.cidr6 t.ipv6;
        default = {};
        description = "IPv6 prefix and gateway.";
      };
      nameservers = mkOption {
        type = types.listOf t.ip;
        default = [];
        description = "DNS resolvers for hosts on this network.";
      };
      mtu = mkOption {
        type = types.nullOr (types.ints.between 68 65535);
        default = null;
        description = "Network MTU, when it differs from the link default.";
      };
      vlan = mkOption {
        type = types.nullOr (types.ints.between 1 4094);
        default = null;
        description = "802.1Q VLAN id, when the network is tagged.";
      };
    };
  };

  link = types.submodule {
    options = {
      interface = mkOption {
        type = types.nullOr t.ifname;
        default = null;
        description = "Kernel interface name, e.g. enp4s0.";
      };
      mac = mkOption {
        type = types.nullOr t.mac;
        default = null;
        description = "Hardware address, for udev renaming or DHCP reservations.";
      };
      network = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Name of the `networks` entry this link attaches to.";
      };
      ipv4 = mkOption {
        type = types.listOf t.cidr4;
        default = [];
        description = "Static IPv4 addresses with prefix length (netif `static.ipv4` shape).";
      };
      ipv6 = mkOption {
        type = types.listOf t.cidr6;
        default = [];
        description = "Static IPv6 addresses with prefix length (netif `static.ipv6` shape).";
      };
    };
  };

  host = types.submodule {
    options = {
      fqdn = mkOption {
        type = types.nullOr t.dnsName;
        default = null;
        description = "Fully qualified name the host is reached by.";
      };
      targetHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Deploy target, `[user@]host`, for clan `deploy.targetHost`.";
      };
      links = mkOption {
        type = types.attrsOf link;
        default = {};
        description = "Links keyed by logical name (lan, wifi, sfp0), matching netif link names.";
      };
      addresses = mkOption {
        type = types.attrsOf t.ip;
        default = {};
        description = "Named addresses that are not on a link: failover IPs, VIPs, load-balancer IPs.";
      };
    };
  };
in {
  options = {
    meta = {
      placeholder = mkOption {
        type = types.bool;
        description = ''
          True in external-systems/not-secrets, false in external-systems/secrets.
          Deploy tooling refuses to run when this is true. No default:
          every values tree must say which one it is.
        '';
      };
      description = mkOption {
        type = types.str;
        default = "";
        description = "Free text describing this values tree.";
      };
    };

    domains = mkOption {
      type = types.attrsOf t.dnsName;
      default = {};
      description = "DNS names and zones by purpose, e.g. `primary`.";
    };

    networks = mkOption {
      type = types.attrsOf network;
      default = {};
      description = "Network segments by name (site LAN, uplink, mesh).";
    };

    hosts = mkOption {
      type = types.attrsOf host;
      default = {};
      description = "Per-machine facts keyed by clan machine name.";
    };

    ports = mkOption {
      type = types.attrsOf t.port;
      default = {};
      description = "Port numbers by purpose, e.g. `wireguard-kube-mesh`.";
    };

    extra = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = ''
        Escape hatch for values that have no typed section yet. When a kind
        of value repeats, give it a typed section in a schema bump.
      '';
    };

    assertions = mkOption {
      type = types.listOf (types.submodule {
        options = {
          assertion = mkOption {
            type = types.bool;
            description = "Must hold.";
          };
          message = mkOption {
            type = types.str;
            description = "Shown when it does not.";
          };
        };
      });
      internal = true;
      default = [];
      description = "Cross-field invariants, checked by lib.mkValues.";
    };
  };

  config.assertions = lib.flatten (lib.mapAttrsToList (
      hostName: hostCfg:
        lib.mapAttrsToList (linkName: linkCfg: {
          assertion = linkCfg.network == null || config.networks ? ${linkCfg.network};
          message = "hosts.${hostName}.links.${linkName}.network = \"${toString linkCfg.network}\" names no entry in `networks`.";
        })
        hostCfg.links
    )
    config.hosts);
}
