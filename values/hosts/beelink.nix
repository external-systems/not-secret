{
  hosts.beelink = {
    targetHost = "root@beelink";
    links.wifi = {
      interface = "wlan0";
      network = "home-lan";
      ipv4 = ["198.51.100.230/24"];
      ipv6 = ["2001:db8:1::30/64"];
    };
  };
}
