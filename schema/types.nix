# Syntactic leaf types shared by every schema section. They reject typos at
# eval time; they do not prove an address is routable or a name resolves.
{lib}: let
  inherit (lib) types;

  octet = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])";
  ipv4Re = "${octet}(\\.${octet}){3}";
  # Loose IPv6 shape (hex groups, colons, optional embedded IPv4); the
  # extra check below enforces at most one "::" and at most 8 groups.
  ipv6Re = "[0-9a-fA-F:]*:[0-9a-fA-F:]*(${ipv4Re})?";
  label = "[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?";

  ipv6Ok = s: let
    double = builtins.length (lib.splitString "::" s) - 1;
    groups = builtins.length (lib.splitString ":" s);
  in
    double <= 1 && groups <= 9;

  matches = re: s: builtins.match re s != null;
  withPrefix = maxLen: s: let
    parts = lib.splitString "/" s;
    len = lib.toIntBase10 (lib.last parts);
  in
    builtins.length parts == 2 && matches "[0-9]{1,3}" (lib.last parts) && len <= maxLen;
  addrOf = s: builtins.head (lib.splitString "/" s);

  named = name: description: type:
    type
    // {
      inherit name description;
    };
in rec {
  ipv4 = named "ipv4" "IPv4 address" (types.strMatching ipv4Re);

  ipv6 = named "ipv6" "IPv6 address" (types.addCheck (types.strMatching ipv6Re) ipv6Ok);

  ip = types.either ipv4 ipv6;

  cidr4 =
    named "cidr4" "IPv4 address with prefix length, e.g. 192.0.2.10/24"
    (types.addCheck types.str (s: withPrefix 32 s && ipv4.check (addrOf s)));

  cidr6 =
    named "cidr6" "IPv6 address with prefix length, e.g. 2001:db8::10/64"
    (types.addCheck types.str (s: withPrefix 128 s && ipv6.check (addrOf s)));

  mac =
    named "mac" "MAC address, colon separated, e.g. 00:00:5e:00:53:01"
    (types.strMatching "[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}");

  dnsName =
    named "dnsName" "DNS name, e.g. host.example.com"
    (types.addCheck (types.strMatching "${label}(\\.${label})*") (s: builtins.stringLength s <= 253));

  # Linux IFNAMSIZ is 16 including the NUL byte.
  ifname =
    named "ifname" "Linux interface name (max 15 characters)"
    (types.strMatching "[^/:[:space:]]{1,15}");

  # Hetzner Storage Box account (u123456) or sub-account (u123456-sub1).
  storageboxUser =
    named "storageboxUser" "Hetzner Storage Box account id, e.g. u000000 or u000000-sub1"
    (types.strMatching "u[0-9]+(-sub[0-9]+)?");

  inherit (types) port;
}
