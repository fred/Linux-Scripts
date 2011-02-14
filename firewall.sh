#!/bin/bash
# Fredz firewall
# Stealth and OpenVPN-aware firewall.

# eth0 is connected to the internet.
# tun0 is connected to a private subnet such as OpenVPN.


# Kernel configuration.
#------------------------------------------------------------------------------

# Enable IP forwarding.
# On => Off = (reset)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Enable IP spoofing protection
#for i in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 1 > $i; done

# Protect against SYN flood attacks
#echo 1 > /proc/sys/net/ipv4/tcp_syncookies


# Change this subnet to correspond to your private
# ethernet subnet.  Home will use HOME_NET/24 and
# Office will use OFFICE_NET/24.
PRIVATE=10.8.0.0/16
echo "Private Address (trusted): ${PRIVATE}"
PRIVATE2=10.9.0.0/16
echo "Private Address (trusted): ${PRIVATE2}"

# Loopback address
LOOP=127.0.0.1
echo "Loop Address: ${LOOP}"

# FULLY Trusted networks. 
OFFICE="124.124.124.124"
HOME="123.123.123.110"
TRUSTED="$HOME $OFFICE"

# Eternal Ports
EXT_PORTS="80 443 22 2222 5678 8000 22022 55455"

# Delete old iptables rules
# and temporarily block all traffic.
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -F

# Set default policies
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP

iptables -N LOGDROP
iptables -A LOGDROP -m limit --limit 90/min -j LOG --log-prefix "iptables: " --log-level info
iptables -A LOGDROP -j DROP

# Always allow loop
echo "Allow local loopback ${LOOP}"
iptables -A INPUT -s $LOOP -j ACCEPT
iptables -A INPUT -d $LOOP -j ACCEPT


echo "Keep state of connections from local machine and private subnets"
iptables -A INPUT   -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "Allow all outgoing connections"
iptables -A OUTPUT  -m state --state NEW  -j ACCEPT
iptables -A FORWARD -m state --state NEW  -j ACCEPT

# Allow incoming pings (can be disabled)
echo "Allow only Pings (icmp-type: echo-request)"
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT


echo "Drops Multicast"
iptables -A INPUT -m pkttype --pkt-type broadcast -i eth0 -j LOGDROP
iptables -A INPUT -m pkttype --pkt-type multicast -i eth0 -j LOGDROP
iptables -A INPUT -d 255.255.255.255/32 -i eth0 -j LOGDROP
iptables -A INPUT -d 192.168.0.255/32 -i eth0 -j LOGDROP
iptables -A INPUT -s 224.0.0.0/8 -i eth0 -j LOGDROP
iptables -A INPUT -d 224.0.0.0/8 -i eth0 -j LOGDROP
iptables -A INPUT -s 255.255.255.255/32 -i eth0 -j LOGDROP
iptables -A INPUT -d 0.0.0.0/32 -i eth0 -j LOGDROP
iptables -A INPUT -m state --state INVALID -i eth0 -j LOGDROP


# Block outgoing NetBios (if you have windows machines running
# on the private subnet).  This will not affect any NetBios
# traffic that flows over the VPN tunnel, but it will stop
# local windows machines from broadcasting themselves to
# the internet.
echo "Blocking Windows ports 137:139 and 445"
iptables -A INPUT -p tcp -m multiport --ports 23,445,137:139 -j LOGDROP
iptables -A INPUT -p udp -m multiport --ports 23,445,137:139 -j LOGDROP

# Drop MongoDB
iptables -A INPUT -p tcp -m multiport --ports 27017,4949,8080 -i eth0 -j LOGDROP

##############################
# Services only for LOOP
##############################
echo "Mysql only allowed from LOOP"
# iptables -A INPUT -p tcp --dport 3306 ! -s $LOOP -j LOG --log-level 7 --log-prefix "iptables denied: MYSQL "
iptables -A INPUT -p tcp --dport 3306 ! -s $LOOP -j LOGDROP

echo "GIT only allowed from LOOP"
iptables -A INPUT -p tcp --dport 9418 ! -s $LOOP -j LOGDROP


##############################
# Trusted
##############################
for IP in $TRUSTED
do
        echo "Allow Fully Trusted only from: ${IP}"
        iptables -A INPUT -s $IP -j ACCEPT
done


#########################
# External Services
#########################

for PORT in $EXT_PORTS
do
    echo "Allow TCP PORT: ${PORT}"
    iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
done


###########
### VPN ###
###########

# Allow incoming OpenVPN packets
# Duplicate the line below for each
# OpenVPN tunnel, changing --dport n
# to match the OpenVPN UDP port.

echo "Allow port UDP 1194 for OpenVPN"
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables -A INPUT -p tcp --dport 1194 -j ACCEPT

echo "Allow Everything from local VPN, WARNING !!!"
iptables -A INPUT -s $PRIVATE -j ACCEPT
iptables -A INPUT -d $PRIVATE -j ACCEPT

iptables -A INPUT -s $PRIVATE2 -j ACCEPT
iptables -A INPUT -d $PRIVATE2 -j ACCEPT

# Allow packets from TUN/TAP devices.
# When OpenVPN is run in a secure mode,
# it will authenticate packets prior
# to their arriving on a tun or tap
# interface.  Therefore, it is not
# necessary to add any filters here,
# unless you want to restrict the
# type of packets which can flow over
# the tunnel.

echo "Allow all in and outgoing OpenVPN packets"
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A INPUT -i tap+ -j ACCEPT
iptables -A FORWARD -i tap+ -j ACCEPT

# echo "Masquerade local VPN subnet on eth0"
iptables -t nat -A POSTROUTING -s $PRIVATE -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s $PRIVATE2 -o eth0 -j MASQUERADE

# Log Dropped Packets
#echo "Logging dropped packages at the mos 90/min"
#iptables -A INPUT -m limit --limit 90/min -j LOG --log-prefix "iptables: " --log-level info

# Drop all other traffic
echo "Drop everything else"
iptables -A INPUT -j LOGDROP


### END ###
