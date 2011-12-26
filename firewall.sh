#!/bin/bash
# Fredz firewall
# Stealth and OpenVPN-aware firewall.

# eth0 is connected to the internet.
# tun0 is connected to a private subnet.


# Kernel configuration.
#-------------------------

# Enable IP forwarding.
# On => Off = (reset)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Enable IP spoofing protection
for i in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 1 > $i; done

# Protect against SYN flood attacks
echo 1 > /proc/sys/net/ipv4/tcp_syncookies


# VPN1
PRIVATE=10.8.0.0/16
echo "Private Address (trusted): ${PRIVATE}"

# VPN2
PRIVATE2=10.9.0.0/16
echo "Private Address (trusted): ${PRIVATE2}"

# Loopback address
LOOP=127.0.0.1
echo "Loop Address: ${LOOP}"

# FULLY Trusted networks. 
TRUSTED="168.120.0.0/16 55.55.55.55 66.66.66.66"
TRUSTED=""

# Eternal Ports
TCP_PORTS="22 80 110 143 443 587 993 995 2222 22022 55455 8080 55455"

# Set to True if you have TOR running
TOR_ENABLED=true

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

echo "Prevent external packets from using loopback addr"
iptables -A INPUT -i eth0 -s $LOOP -j DROP
iptables -A FORWARD -i eth0 -s $LOOP -j DROP
iptables -A INPUT -i eth0 -d $LOOP -j DROP
iptables -A FORWARD -i eth0 -d $LOOP -j DROP

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


if [ $TOR_ENABLED ] 
then
	echo "Allowing TOR ports"
	iptables -A INPUT -i eth+ -p tcp -m multiport --ports 9001,9050,9051,9090,9091 -j ACCEPT
	iptables -A INPUT -i eth+ -p udp -m multiport --ports 9001,9050,9051,9090,9091 -j ACCEPT
fi


##############################
# Trusted
##############################
for IP in $TRUSTED
do
    echo "Allow Fully Trusted only from: ${IP}"
    iptables -A INPUT -i eth+ -s $IP -j ACCEPT
done


#########################
# External Services
#########################

for PORT in $TCP_PORTS
do
    echo "Allow TCP PORT: ${PORT}"
    iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
done


#################
### ALLOW UDP ###
#################
echo "Allowing ALL UDP"
iptables -A INPUT -p udp -j ACCEPT



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

echo "Masquerade local VPN subnet on eth0"
iptables -t nat -A POSTROUTING -s $PRIVATE -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s $PRIVATE2 -o eth0 -j MASQUERADE


# Log Dropped Packets
echo "Logging dropped packages at the mos 90/min"
iptables -A INPUT -m limit --limit 90/min -j LOG --log-prefix "iptables denied: " --log-level 7

# Drop all other traffic
echo "Drop everything else"
iptables -A INPUT -j DROP


### END ###