#! /bin/bash
#=======================================================================#
#                   FreeHPC Basic Setup for CentOS 7.9                  #
#=======================================================================#

# Load environment variables
. $HOME/env.conf

# check environment variable
if [ -z "$SOFT_SERV" ]; then
    echo "Error: The environmenal variable SOFT_SERV is empty."
    exit -1
fi

# obtain system information: ip addr show ib0|grep -i link|awk '{print $2}'
mst_guid=$(ip addr show ib0|grep infiniband|awk '{print $2}'|awk -F: '{for(i=NF-7; i<=NF; i++) printf "%s", $i; print ""}')
MST_IP=$(ip addr show $IB_DEV|grep "inet "|awk -F "/" '{print $1}'|awk '{print $2}')
IP_PRE=$(echo $MST_IP|awk -F "." '{print $1"."$2"."$3}')


# Download ibpxe program from abhpc server
rm -rf /usr/bin/ibpxe
wget $SOFT_SERV/ibpxe/ibpxe-${mst_guid}.el7 --no-check-certificate -O /usr/bin/ibpxe
chmod +x /usr/bin/ibpxe

# Check if ibpxe is ready
if [ ! -f /usr/bin/ibpxe ]; then
    echo "Error: /usr/bin/ibpxe does not exist."
    exit 0
fi

# Check if guid.txt is ready
if [ ! -f /root/Admin/mac/guid.txt ]; then
    echo "Error: /root/Admin/mac/guid.txt does not exist. Please collect the GUIDs information into this file!"
    exit 0
fi

# Create guid-ip.txt and dhcpd.conf files
rm -rf /root/Admin/ibpxe/abhpc
mkdir -p /root/Admin/ibpxe/abhpc

# Generate guid-ip.txt
#printf "00:00:00:00:00:00:00:00\t\t%s\t\tmaster\n" "$MST_IP" > /root/Admin/ibpxe/abhpc/guid-ip.txt
#awk -v pre=$IP_PRE '{printf "%s\t\t%s.%d\t\tn%03d\n", $0, pre, NR, NR;}' /root/Admin/mac/guid.txt >> /root/Admin/ibpxe/abhpc/guid-ip.txt


# Generate dhcpd.conf file
cat << EOF > /root/Admin/ibpxe/abhpc/dhcpd.conf
default-lease-time                      300;
max-lease-time                          300;
option subnet-mask                      255.255.255.0;
option domain-name-servers              $MST_IP;
option domain-name                     "abhpc.com";
ddns-update-style                       none;
server-name                            abhpc;

allow booting;
allow bootp;

option arch code 93 = unsigned integer 16;
option space pxelinux;
option pxelinux.magic      code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;

site-option-space "pxelinux";
if exists dhcp-parameter-request-list {
    option dhcp-parameter-request-list = concat(option dhcp-parameter-request-list,d0,d1,d2,d3);
}
if option arch = 00:06 {
    filename "bootia32.efi";
} else if option arch = 00:07 {
    filename "bootx64.efi";
} else if option arch = 00:09 {
    filename "bootx64.efi";
} else {
    filename "pxelinux.0";
}

class "ABHPC-Client" {
  match if
  (substring(option vendor-class-identifier, 0, 9) = "PXEClient") or
  (substring(option vendor-class-identifier, 0, 9) = "Etherboot") or
  (substring(option vendor-class-identifier, 0, 10) = "ABHPCClient") ;
}
subnet $IP_PRE.0 netmask 255.255.255.0 {
    option subnet-mask  255.255.255.0;
    option routers $MST_IP;
    next-server $MST_IP;
EOF

num=1
for i in $(cat /root/Admin/mac/guid.txt)
do
    guid_i=$i
    mac_i=$(echo $i|awk -F ":" '{print $1":"$2":"$3":"$6":"$7":"$8}')
    #echo $i $mac_i
    printf "\thost %s%03d {\n" "$CLI_PRE" "$num"
    printf "\t\thardware ethernet  %s;\n" "$mac_i"
    printf "\t\toption dhcp-client-identifier = ff:00:00:00:00:00:02:00:00:02:c9:00:%s;\n" "$guid_i"
    printf "\t\tfixed-address %s.%d;\n" "$IP_PRE" "$num"
    printf "\t}\n"
    num=$[$num+1]
done >> /root/Admin/ibpxe/abhpc/dhcpd.conf

echo "}" >> /root/Admin/ibpxe/abhpc/dhcpd.conf


# Revise kernerl
cd /root/Admin/ibpxe
wget $SOFT_SERV/ibpxe/rootfs.tgz

# Check if guid.txt is ready
if [ ! -f rootfs.tgz ]; then
    echo "Error: rootfs.tgz does not exist."
    exit 0
fi

tar -vxf rootfs.tgz
rm -rf rootfs.tgz
ibpxe -c abhpc/
