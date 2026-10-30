{
  hosts.kamrui-h1 = {
    targetHost = "root@kamrui-h1";
    links.wifi = {
      interface = "wlan0";
      network = "home-lan";
      ipv4 = ["198.51.100.250/24"];
      ipv6 = ["2001:db8:1::50/64"];
    };
  };
}
