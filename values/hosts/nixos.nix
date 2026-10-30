{
  hosts.nixos = {
    targetHost = "root@nixos";
    links.lan = {
      interface = "eth0";
      network = "home-lan";
      ipv4 = ["198.51.100.253/24"];
      ipv6 = ["2001:db8:1::10/64"];
    };
  };
}
