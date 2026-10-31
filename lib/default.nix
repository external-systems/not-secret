# Helpers shared by both repos and their consumers. Pure: only nixpkgs lib.
{lib}: let
  t = import ../schema/types.nix {inherit lib;};

  # Every .nix file under dir, except `_`-prefixed ones (import-tree rule).
  valueFiles = dir:
    builtins.filter (
      f: lib.hasSuffix ".nix" f && !lib.hasPrefix "_" (baseNameOf f)
    ) (lib.filesystem.listFilesRecursive dir);

  # Documentation ranges (RFC 5737, RFC 3849, RFC 7042, RFC 2606/6761).
  docIpv4 = s: lib.any (p: lib.hasPrefix p s) ["192.0.2." "198.51.100." "203.0.113."];
  docIpv6 = s: lib.hasPrefix "2001:db8:" (lib.toLower s);
  docMac = s: lib.hasPrefix "00:00:5e:00:53:" (lib.toLower s);
  docDns = s: let
    n = lib.toLower s;
  in
    lib.any (sfx: n == sfx || lib.hasSuffix ".${sfx}" n) [
      "example"
      "example.com"
      "example.net"
      "example.org"
      "test"
      "invalid"
    ];
  # Values that are neither placeholder nor sensitive: link-local,
  # loopback, unspecified. Allowed in both repos.
  neutral = s: let
    n = lib.toLower s;
  in
    lib.hasPrefix "fe80:" n || n == "::1" || n == "::" || lib.hasPrefix "127." n || n == "0.0.0.0";

  # Classify one string leaf: "placeholder", "neutral", "real" or null
  # (not a network fact, e.g. an interface name).
  classify = s: let
    host = lib.last (lib.splitString "@" s);
    addr = builtins.head (lib.splitString "/" host);
  in
    if neutral addr
    then "neutral"
    else if t.ipv4.check addr
    then
      (
        if docIpv4 addr
        then "placeholder"
        else "real"
      )
    else if t.mac.check addr
    then
      (
        if docMac addr
        then "placeholder"
        else "real"
      )
    else if lib.hasInfix ":" addr && t.ipv6.check addr
    then
      (
        if docIpv6 addr
        then "placeholder"
        else "real"
      )
    else if lib.hasInfix "." addr && t.dnsName.check addr
    then
      (
        if docDns addr
        then "placeholder"
        else "real"
      )
    else null;

  # Keys that hold free text or kernel names, never network facts.
  skipKeys = ["description" "interface" "network" "link" "kind"];

  leaves = path: v:
    if builtins.isAttrs v
    then
      lib.concatLists (lib.mapAttrsToList (
          k: v':
            lib.optionals (!builtins.elem k skipKeys) (leaves (path ++ [k]) v')
        )
        v)
    else if builtins.isList v
    then lib.concatLists (lib.imap0 (i: leaves (path ++ [(toString i)])) v)
    else if builtins.isString v
    then [
      {
        path = lib.concatStringsSep "." path;
        value = v;
        class = classify v;
      }
    ]
    else [];

  report = what: hits:
    lib.concatMapStringsSep "\n" (h: "  ${h.path} = \"${h.value}\" (${what})") hits;
in rec {
  schemaVersion = 1;

  # Evaluate a values directory against the schema; throws on assertion
  # failures, returns the plain attrset consumers read.
  schemaModule = ../schema;

  mkValues = dir: mkValuesFrom (valueFiles dir);

  # Evaluate a list of value modules against the schema.
  mkValuesFrom = modules: let
    inherit (lib.evalModules {modules = [schemaModule] ++ modules;}) config;
    failed = builtins.filter (a: !a.assertion) config.assertions;
  in
    if failed != []
    then throw "values:\n${lib.concatMapStringsSep "\n" (a: "- ${a.message}") failed}"
    else removeAttrs config ["assertions" "_module"];

  # "192.0.2.10/24" -> "192.0.2.10"
  addr = cidr: builtins.head (lib.splitString "/" cidr);

  # "192.0.2.10/24" -> 24
  prefix = cidr: lib.toIntBase10 (lib.last (lib.splitString "/" cidr));

  # The attribute tree with every leaf replaced by null. Two values trees
  # with equal shapes can be swapped without breaking a consumer's eval.
  shapeOf = v:
    if builtins.isAttrs v
    then builtins.mapAttrs (_: shapeOf) v
    else null;

  # Attribute paths present in one shape but not the other.
  shapeDiff = a: b: let
    go = path: x: y:
      lib.concatLists (lib.mapAttrsToList (
          k: xv: let
            p = path ++ [k];
          in
            if !(y ? ${k})
            then [(lib.concatStringsSep "." p)]
            else if builtins.isAttrs xv && builtins.isAttrs y.${k}
            then go p xv y.${k}
            else []
        )
        x);
  in {
    onlyLeft = go [] a b;
    onlyRight = go [] b a;
  };

  # Leaves that look like real (non-documentation) network facts.
  realLeaves = values: builtins.filter (h: h.class == "real") (leaves [] values);

  # Leaves still inside documentation ranges.
  placeholderLeaves = values: builtins.filter (h: h.class == "placeholder") (leaves [] values);

  # Throwing guards for checks and deploy scripts; return true on success.
  assertPlaceholdersOnly = values: let
    hits = realLeaves values;
  in
    if !values.meta.placeholder
    then throw "meta.placeholder must be true in a public values tree"
    else if hits != []
    then throw "real-looking values in a public values tree:\n${report "not a documentation range" hits}"
    else true;

  assertNoPlaceholders = values: let
    hits = placeholderLeaves values;
  in
    if values.meta.placeholder
    then throw "meta.placeholder is true: these are placeholder values, refusing to use them for a real deploy"
    else if hits != []
    then throw "placeholder values left in a private values tree:\n${report "documentation range" hits}"
    else true;

  assertSameShape = reference: values: let
    d = shapeDiff (shapeOf reference) (shapeOf values);
  in
    if d.onlyLeft == [] && d.onlyRight == []
    then true
    else
      throw ''
        values shape differs from the reference:
        ${lib.optionalString (d.onlyLeft != []) "  missing here: ${lib.concatStringsSep ", " d.onlyLeft}\n"}${lib.optionalString (d.onlyRight != []) "  only here:    ${lib.concatStringsSep ", " d.onlyRight}"}
      '';
}
