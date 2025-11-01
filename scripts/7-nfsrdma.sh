#! /bin/bash
#=======================================================================#
#                    ABHPC Basic Setup for CentOS 7.9                   #
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


# Change NFS threads number
cat << EOF > /etc/sysconfig/nfs
RPCNFSDARGS=""
RPCNFSDCOUNT=$NFSD_NUM
RPCMOUNTDOPTS=""
STATDARG=""
SMNOTIFYARGS=""
RPCIDMAPDARGS=""
RPCGSSDARGS=""
GSS_USE_PROXY="yes"
BLKMAPDARGS=""
EOF

# Add nfsrdma ports
sed -i "s@ExecStartPost=.*@ExecStartPost=-/bin/sh -c 'if systemctl -q is-active gssproxy; then systemctl reload gssproxy ; fi; echo \"rdma 20049\" > /proc/fs/nfsd/portlist'@" /usr/lib/systemd/system/nfs-server.service
systemctl daemon-reload

# For server
modprobe svcrdma
modprobe xprtrdma
service nfs-server restart
#echo "rdma 20049" > /proc/fs/nfsd/portlist

cat << EOF >> /etc/rc.d/rc.local
modprobe svcrdma
modprobe xprtrdma
service nfs-server restart
EOF
awk '!seen[$0]++' /etc/rc.d/rc.local > /etc/rc.d/rc.local.uniq
mv -f /etc/rc.d/rc.local.uniq /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local


# For computing nodes
cat << EOF > /opt/etc/fstab.add
$MST_IP:/usr/lib64             /lib64      nfs    ro,soft,nfsvers=3,tcp,,defaults        0 0
$MST_IP:/usr/lib               /lib        nfs    ro,soft,nfsvers=3,tcp,,defaults        0 0
$MST_IP:/usr/bin               /bin        nfs    ro,soft,nfsvers=3,tcp,,defaults        0 0
$MST_IP:/usr/sbin              /sbin       nfs    ro,soft,nfsvers=3,tcp,,defaults        0 0
EOF

cat << EOF > /root/Admin/IB/usr-nfs.sh
#! /bin/bash

nodeip=\$(ls /tftpboot/nodes/)

for i in \$nodeip
do
        opn="/tftpboot/nodes/\$i"
        cat /opt/etc/fstab.add >> \$opn/etc/fstab     
        awk '!seen[\$0]++' \$opn/etc/fstab > \$opn/etc/fstab.uniq
        mv -f \$opn/etc/fstab.uniq \$opn/etc/fstab
done
EOF

sh /root/Admin/IB/usr-nfs.sh

cat << EOF > /root/Admin/IB/nfsrdma.sh
#! /bin/bash

nodeip=\$(ls /tftpboot/nodes/)

for i in \$nodeip
do
        opn="/tftpboot/nodes/\$i"
        sed -i "s@nfsvers=3,tcp@nfsvers=3,rdma,port=20049@g" \$opn/etc/fstab
        awk '!seen[\$0]++' \$opn/etc/fstab > \$opn/etc/fstab.uniq
        mv -f \$opn/etc/fstab.uniq \$opn/etc/fstab
done
EOF

sh /root/Admin/IB/nfsrdma.sh