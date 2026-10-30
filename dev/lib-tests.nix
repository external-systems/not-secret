# Eval tests for the schema and the guards. Each case must hold; the
# result is true or a throw naming the failing case.
{
  lib,
  vlib,
}: let
  fails = v: !(builtins.tryEval (builtins.deepSeq v v)).success;
  evalWith = module:
    (lib.evalModules {modules = [vlib.schemaModule {meta.placeholder = true;} module];}).config;
  base = {
    meta.placeholder = true;
    hosts.h.links.l.ipv4 = ["192.0.2.1/24"];
  };
  cases = {
    rejectsBadIpv4 = fails (evalWith {hosts.h.links.l.ipv4 = ["192.0.2.300/24"];}).hosts;
    rejectsMissingPrefix = fails (evalWith {hosts.h.links.l.ipv4 = ["192.0.2.1"];}).hosts;
    rejectsBadMac = fails (evalWith {hosts.h.links.l.mac = "00:00:5e:00:53";}).hosts;
    rejectsLongIfname = fails (evalWith {hosts.h.links.l.interface = "averyveryverylongname";}).hosts;
    rejectsTwoDoubleColons = fails (evalWith {hosts.h.addresses.a = "2001:db8::1::2";}).hosts;
    acceptsIpv6Cidr = (evalWith {hosts.h.links.l.ipv6 = ["2001:db8::10/64"];}).hosts.h.links.l.ipv6 == ["2001:db8::10/64"];
    addrAndPrefix = vlib.addr "192.0.2.10/24" == "192.0.2.10" && vlib.prefix "192.0.2.10/24" == 24;
    placeholderGuardPasses = vlib.assertPlaceholdersOnly base;
    placeholderGuardCatchesRealIp = fails (vlib.assertPlaceholdersOnly (lib.recursiveUpdate base {hosts.h.links.l.ipv4 = ["8.8.8.8/32"];}));
    placeholderGuardCatchesRealDomain = fails (vlib.assertPlaceholdersOnly (base // {domains.primary = "andrewlee.fun";}));
    placeholderGuardCatchesRealMac = fails (vlib.assertPlaceholdersOnly (lib.recursiveUpdate base {hosts.h.links.l.mac = "a8:a1:59:00:00:01";}));
    linkLocalIsNeutral = vlib.assertPlaceholdersOnly (lib.recursiveUpdate base {networks.n.ipv6.gateway = "fe80::1";});
    realGuardCatchesPlaceholder = fails (vlib.assertNoPlaceholders (base // {meta.placeholder = false;}));
    realGuardCatchesFlag = fails (vlib.assertNoPlaceholders (lib.recursiveUpdate base {hosts.h.links.l.ipv4 = ["10.0.0.1/8"];}));
    realGuardPasses = vlib.assertNoPlaceholders {
      meta.placeholder = false;
      hosts.h.links.l.ipv4 = ["10.0.0.1/8"];
    };
    shapeParityPasses = vlib.assertSameShape base (lib.recursiveUpdate base {hosts.h.links.l.ipv4 = ["10.0.0.1/8" "10.0.0.2/8"];});
    shapeParityCatchesExtraHost = fails (vlib.assertSameShape base (lib.recursiveUpdate base {hosts.other = {};}));
    bareAddressCoerces =
      (evalWith {hosts.h.addresses.a = "192.0.2.5";}).hosts.h.addresses.a
      == {
        address = "192.0.2.5";
        kind = "additional";
        link = null;
      };
    rejectsBadAddressKind =
      fails
      (evalWith {
        hosts.h.addresses.a = {
          address = "192.0.2.5";
          kind = "bogus";
        };
      }).hosts;
    acceptsMixedFamilyPrefixes =
      builtins.attrNames
      (evalWith {
        hosts.h.prefixes = {
          v4.cidr = "198.51.100.0/28";
          v6.cidr = "2001:db8:2::/64";
        };
      }).hosts.h.prefixes
      == ["v4" "v6"];
    placeholderGuardCatchesRealPrefix = fails (vlib.assertPlaceholdersOnly (lib.recursiveUpdate base {hosts.h.prefixes.p.cidr = "2a01:4f9::/64";}));
    danglingAddressLinkRejected = fails (vlib.mkValuesFrom [
      {
        meta.placeholder = true;
        hosts.h.addresses.a = {
          address = "192.0.2.5";
          link = "nope";
        };
      }
    ]);
    danglingNetworkRejected = fails (vlib.mkValuesFrom [
      {
        meta.placeholder = true;
        hosts.h.links.l.network = "nope";
      }
    ]);
  };
  failed = builtins.attrNames (lib.filterAttrs (_: ok: !ok) cases);
in
  if failed == []
  then true
  else throw "lib-tests failed: ${lib.concatStringsSep ", " failed}"
