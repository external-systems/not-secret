{
  hosts.hp-notebook = {
    targetHost = "root@hp-notebook";
    links.wifi = {
      interface = "wlan0";
      network = "home-lan";
      ipv4 = ["198.51.100.246/24"];
      ipv6 = ["2001:db8:1::15/64"];
    };
  };
}
