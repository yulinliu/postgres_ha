# PostgreSQL 9.3 hot_standby Script

Linux Virtual Host Setting

1. Add Virtual Network Interface

  cp /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0:ha
  
  vi /etc/sysconfig/network-scripts/ifcfg-eth0:ha
  
      DEVICE=eth2:ha
      BOOTPROTO=static
      BROADCAST=10.1.191.255
      HWADDR=00:0C:29:EF:FD:83
      IPADDR=10.1.185.216
      NETMASK=255.255.248.0
      NETWORK=10.1.0.0
      ONBOOT=no

2. Start Test

  /sbin/ifconfig eth2:ha 10.1.185.216 broadcast 10.1.191.255 netmask 255.255.248.0 up
  
  /sbin/route add -host 10.1.185.216 dev eth2:ha
  
  /sbin/arping -I eth2 -c 3 -s 10.1.185.216 10.1.0.1

  ping 10.1.185.216
  
3. Stop Test

  /sbin/ifconfig eth2:ha 10.1.185.216 broadcast 10.1.191.255 netmask 255.255.248.0 down

  ping 10.1.185.216
  
Start Shell Script

    sh postgres_ha.sh &
  
