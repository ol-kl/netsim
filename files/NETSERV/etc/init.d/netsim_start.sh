#!/bin/zsh

echo "The services required for NetSim are about to start..."
echo
echo "Starting dhcpd on eth0.20 eth0.30...i"
dhcpd eth0.20 eth0.30
if [ $? -eq 0 ]; then echo "DHCPd ok"
else echo "DHCPd fail"; return 1
fi
echo "Starting atftpd..."
atftpd --daemon  --port 69 /srv/tftp/
if [ $? -eq 0 ]; then echo "atftpd ok"
else "atftpd fail"; return 2
fi
echo "Starting Apache2 daemon"
apache2ctl start
if [ $? -eq 0 ]; then echo "Apache2 ok"
else echo "Apache2 fail"; return 3
fi
