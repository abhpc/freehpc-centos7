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
if [ -z "$FS_MST" ]; then
    echo "Error: The environmenal variable FS_MST is empty."
    exit -1
fi
if [ -z "$FS_MOUNT" ]; then
    echo "Error: The environmenal variable FS_MOUNT is empty."
    exit -1
fi

# Install beegfs packages
cd /tmp
wget $SOFT_SERV/beegfs-7.2.15.el7.tgz
tar -vxf beegfs-7.2.15.el7.tgz
cd beegfs-7.2.15.el7/
yum localinstall -y *.rpm
cd ..
rm -rf beegfs-7.2.15.el7*

# Enable Client
sed -i 's/^buildArgs.*/buildArgs=-j8 OFED_INCLUDE_PATH=\/usr\/src\/ofa_kernel\/default\/include/' /etc/beegfs/beegfs-client-autobuild.conf
/etc/init.d/beegfs-client rebuild
/opt/beegfs/sbin/beegfs-setup-client -m $FS_MST
sed -i 's/^connAuthFile.*/connAuthFile = \/etc\/beegfs\/connauthfile/' /etc/beegfs/*.conf
echo "$FS_MOUNT /etc/beegfs/beegfs-client.conf" > /etc/beegfs/beegfs-mounts.conf

scp $FS_MST:/etc/beegfs/connauthfile /etc/beegfs/
if [ -f "/etc/beegfs/connauthfile" ]; then
    systemctl enable --now beegfs-helperd.service
    systemctl enable --now beegfs-client.service
fi