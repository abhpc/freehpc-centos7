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
if [ -z "$MST_IP" ]; then
    echo "Error: The environmenal variable MST_IP is empty."
    exit -1
fi

# Install net-tools and openssl
yum install -y wget net-tools openssl-devel  kernel-devel python-devel createrepo bash-comp* chrony pdsh msr-tools ipmitool
yum install -y redhat-rpm-config rpm-build

# Disable firewalld and enable iptables
systemctl stop firewalld
systemctl mask firewalld
yum install iptables-services -y
systemctl enable iptables
iptables -F
mkdir -p /opt/etc
iptables-save >/opt/etc/iptables.none
echo "/usr/sbin/iptables-restore /opt/etc/iptables.none" >> /etc/rc.d/rc.local
awk '!seen[$0]++' /etc/rc.d/rc.local > /etc/rc.d/rc.local.tmp
mv -f /etc/rc.d/rc.local.tmp /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local

# Disable Selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0

# Install redhat-lsb-core
yum install redhat-lsb-core python3 -y

# Install epel and bash-completion packages
#yum install epel-release -y
yum install bash-comp* -y

# Install Development tools
yum groupinstall -y "Development Tools"
yum install -y glibc-static libstdc++-static blas-devel lapack-devel python-devel

# Install mate Desktop (optional)
yum groupremove "Server with GUI" "xfce" "mate" "KDE Plasma Workspaces" "cinnamon" -y
yum groupinstall -y "mate" "KDE Plasma Workspaces"
yum install -y xorg-x11-server-Xorg
yum groupinstall -y Fonts

# ANSYS and abaqus requirements
yum install -y xorg-x11-fonts-100dpi xorg-x11-fonts-75dpi libpng12-devel libXp-devel xterm motif-devel libXxf86vm-devel xcb-util-renderutil
yum install -y bzip2-libs expat fontconfig freetype glib2 glibc libICE \
                libSM libX11 libXau libXext libXft libXrender libpng libuuid \
                libxcb libxkbcommon libxkbcommon-x11 pcre xcb-util \
                xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm zlib \
                xcb-util-wm compat-libstdc++-33

# system fonts
yum install xorg-x11-fonts* -y
#yum install -y $SOFT_SERV/msttcore-fonts-installer-2.6-1.noarch.rpm


# Install MLNX_OFED as Infiniband driver
cd $HOME
wget $SOFT_SERV/MLNX_OFED_LINUX-4.9-7.1.0.0-rhel7.9-x86_64.tgz --no-check-certificate
tar -vxf MLNX_OFED_LINUX-4.9-7.1.0.0-rhel7.9-x86_64.tgz
cd MLNX_OFED_LINUX-4.9-7.1.0.0-rhel7.9-x86_64
yum install pciutils lsof gtk2 atk cairo tk -y
./mlnxofedinstall --add-kernel-support --with-nfsrdma --without-fw-update <<< y
dracut -f

# Configure Infiniband card
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-bond0
DEVICE=bond0
TYPE=Bond
BONDING_MASTER=yes
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=bond0
ONBOOT=yes
BONDING_OPTS="mode=active-backup miimon=100 primary=ib0 updelay=100 downdelay=100 max_bonds=2 fail_over_mac=1"
IPADDR=$MST_IP
PREFIX=24
MTU=65520
CONNECTED_MODE=yes
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-ib0
TYPE=Infiniband
NAME=ib0
DEVICE=ib0
ONBOOT=yes
MASTER=bond0
SLAVE=yes
MTU=65520
CONNECTED_MODE=yes
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-ib1
TYPE=Infiniband
NAME=ib1
DEVICE=ib1
ONBOOT=yes
MASTER=bond0
SLAVE=yes
MTU=65520
CONNECTED_MODE=yes
EOF

cat << EOF >> /etc/rc.local
/etc/init.d/openibd start
/etc/init.d/opensmd start
echo connected > /sys/class/net/ib0/mode
modprobe svcrdma
modprobe xprtrdma
EOF

# Enable chronyd
cat << EOF > /etc/chrony.conf
server ntp.ntsc.ac.cn iburst
driftfile /var/lib/chrony/chrony.drift
makestep 0.1 3
rtcsync
allow all
local stratum 10
EOF
systemctl enable --now chronyd.service

cat << EOF > /etc/profile.d/auto-gen-sshkey.sh
#!/bin/bash

user=\`whoami\`
home=\$HOME

if [ "\$user" == "nobody" ] ; then
    echo Not creating SSH keys for user \$user
elif [ \`echo \$home | wc -w\` -ne 1 ] ; then
    echo cannot determine home directory of user \$user
else
    if ! [ -d \$home ] ; then
        echo cannot find home directory \$home
    elif ! [ -w \$home ]; then
        echo the home directory \$home is not writtable
    else
        file=\$home/.ssh/id_rsa
        type=rsa
        if [ ! -e \$file ] ; then
            echo generating ssh file \$file ...
            ssh-keygen -t \$type -N '' -f \$file
        fi

        file=\$home/.bashrc
        if [ ! -e \$file ] ; then
            cp /etc/skel/.bashrc \$home/.bashrc
            cp /etc/skel/.bash_logout  \$HOME/.bash_logout
            cp /etc/skel/.bash_profile \$HOME/.bash_profile
        fi

        id="\`cat \$home/.ssh/id_rsa.pub\`"
        file=\$home/.ssh/authorized_keys
        if ! grep "^\$id\\\$" \$file >/dev/null 2>&1 ; then
            echo adding id to ssh file \$file
            echo \$id >> \$file
        fi

        file=\$home/.ssh/config
        if ! grep 'StrictHostKeyChecking.*no' \$file >/dev/null 2>&1 ; then
            echo adding StrictHostKeyChecking=no to ssh config file \$file
            echo 'StrictHostKeyChecking no' >> \$file
        fi

        chmod 600 \$home/.ssh/authorized_keys
        chmod 600 \$home/.ssh/config
    fi
fi
EOF

chmod +x /etc/profile.d/auto-gen-sshkey.sh

cat << EOF >/etc/security/limits.conf
* soft memlock unlimited
* hard memlock unlimited
* soft stack   unlimited
* hard stack   unlimited
* soft memlock unlimited
* hard memlock unlimited
* soft core    0
* hard core    0
EOF

echo 'options ib_ipoib ipoib_enhanced=0' >> /etc/modprobe.d/ib_ipoib.conf
awk '!seen[$0]++' /etc/modprobe.d/ib_ipoib.conf > /etc/modprobe.d/ib_ipoib.conf.tmp
mv -f /etc/modprobe.d/ib_ipoib.conf.tmp /etc/modprobe.d/ib_ipoib.conf
sed -i 's/^SET_IPOIB_CM=.*/SET_IPOIB_CM=yes/' /etc/infiniband/openib.conf

# Clean files
cd $HOME
rm -rf MLNX_OFED_LINUX-4.9-7.1.0.0-rhel7.9-x86_64*

# reboot
reboot
