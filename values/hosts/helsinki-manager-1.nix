{
  hosts.helsinki-manager-1 = {
    targetHost = "deploy@203.0.113.40";
    links = {
      public = {
        interface = "eth0";
        network = "robot-helsinki-manager-1";
        ipv4 = ["203.0.113.40/26"];
        ipv6 = ["2001:db8:2::2/64"];
      };
      kube-mesh = {
        network = "kube-mesh";
        ipv4 = ["192.0.2.2/32"];
        ipv6 = ["2001:db8:64::2/128"];
      };
    };
    # Extra ordered IPv4 for the node's LoadBalancer pool.
    addresses.lb-extra = "203.0.113.27";
  };
}
