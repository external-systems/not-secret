{
  networks = {
    # Home site LAN.
    home-lan = {
      ipv4 = {
        cidr = "198.51.100.0/24";
        gateway = "198.51.100.254";
      };
      ipv6 = {
        cidr = "2001:db8:1::/64";
        gateway = "2001:db8:1::1";
      };
    };

    # Dedicated server public uplink (one routed subnet per server).
    robot-euc-hel-0 = {
      ipv4 = {
        cidr = "203.0.113.0/26";
        gateway = "203.0.113.1";
      };
      ipv6 = {
        cidr = "2001:db8:2::/64";
        gateway = "fe80::1";
      };
    };

    # WireGuard node mesh (Kubernetes node transport).
    kube-mesh = {
      ipv4.cidr = "192.0.2.0/24";
      ipv6.cidr = "2001:db8:64::/64";
      mtu = 1420;
    };
  };
}
