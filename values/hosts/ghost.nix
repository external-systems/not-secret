{
  hosts.ghost = {
    targetHost = "root@ghost";
    links.wifi = {
      interface = "wlan0";
      network = "home-lan";
      ipv4 = ["198.51.100.252/24"];
      ipv6 = ["2001:db8:1::14/64"];
    };
  };
}
