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

# system auth 
cat << EOF > /etc/pam.d/system-auth-ac
#%PAM-1.0
# This file is auto-generated.
# User changes will be destroyed the next time authconfig is run.
auth        required      pam_env.so
auth        required      pam_faildelay.so delay=2000000
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient    pam_ldap.so use_first_pass
auth        required      pam_deny.so

account     required      pam_unix.so broken_shadow
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_ldap.so
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow nis nullok try_first_pass use_authtok
password    sufficient    pam_ldap.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     optional      pam_oddjob_mkhomedir.so umask=0077
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_ldap.so
EOF

# Obtain system information
MST_IP=$(ip addr show $IB_DEV|grep "inet "|awk -F "/" '{print $1}'|awk '{print $2}')

# Download and install drbl packages
wget $SOFT_SERV/drbl.tgz  --no-check-certificate
tar -zxf drbl.tgz
cd drbl
yum localinstall *.rpm -y
cd ..
rm -rf drbl drbl.tgz

# Generate kernel images for diskless cluster
#yum install -y epel-release
yum install -y dhcp tftp-server nfs-utils ypserv ypbind yp-tools dialog tcpdump dos2unix lftp nc expect memtest86+ yum-utils ecryptfs-utils udev
yum install grub2-efi* -y
drblsrv-offline -s `uname -r` -c <<< $'\n'

# Generate client-ip-hostname file for cluster
NET_PRE=$(echo $MST_IP | awk -F. '{print $1"."$2"."$3}')
cat /dev/null > /etc/drbl/client-ip-hostname
for i in `seq 1 $CLI_NUM`
do
  printf "$NET_PRE.$i\t\t${CLI_PRE}%03d\n" "$i" >> /etc/drbl/client-ip-hostname
done

# Generate clients filesystem
mkdir -p /root/Admin/mac
cd /root/Admin/mac
cat /dev/null >  macadr-${IB_DEV}.txt
for i in `seq 1 $CLI_NUM`
do
  echo $(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | awk '{print $0}') >> macadr-${IB_DEV}.txt
done
cd /root/Admin/mac
cat << EOF > push.conf
#Setup for general
[general]
domain=abhpc
nisdomain=abhpc
localswapfile=no
client_init=text
login_gdm_opt=
timed_login_time=
maxswapsize=
ocs_img_repo_dir=/home/partimag
total_client_no=$CLI_NUM
create_account=
account_passwd_length=8
hostname=$CLI_PRE
purge_client=yes
client_autologin_passwd=
client_root_passwd=
client_pxelinux_passwd=
set_client_system_select=no
use_graphic_pxelinux_menu=no
set_DBN_client_audio_plugdev=
open_thin_client_option=no
client_system_boot_timeout=
language=en_US.UTF-8
set_client_public_ip_opt=no
config_file=drblpush.conf
collect_mac=no
run_drbl_ocs_live_prep=yes
drbl_ocs_live_server=
clonezilla_mode=full_clonezilla_mode
live_client_branch=alternative
live_client_cpu_mode=i386
drbl_mode=full_drbl_mode
drbl_server_as_NAT_server=no
add_start_drbl_services_after_cfg=yes
continue_with_one_port=

#Setup for $IB_DEV
[$IB_DEV]
interface=$IB_DEV
mac=macadr-$IB_DEV.txt
ip_start=1
EOF

drblpush -c push.conf <<< $'\n\n'
echo "DHCPDARGS=\"$IB_DEV\"" > /etc/sysconfig/dhcpd
sed -i "s/^option domain-name-servers .*$/option domain-name-servers\t\t$MST_IP;/g" /etc/dhcp/dhcpd.conf
service dhcpd restart

# Generate Infiniband card information
mkdir -p /root/Admin/IB
cd /root/Admin/IB
HEAD=$(echo $MST_IP | awk -F. '{print $1"."$2"."$3}')

cat << EOF > ifcfg-ib.sh
#! /bin/bash

NODEIP=\$(ls /tftpboot/nodes/)

for i in \$NODEIP
do
        opn="/tftpboot/nodes/\$i"
        rm -rf \$opn/etc/sysconfig/network-scripts/ifcfg-en*
        rm -rf \$opn/etc/sysconfig/network-scripts/ifcfg-eth*
        rm -rf \$opn/etc/sysconfig/network-scripts/ifcfg-bond0
        rm -rf \$opn/etc/sysconfig/network-scripts/ifcfg-ib*
        \cp -Rf /opt/etc/ifcfg-ib0 \$opn/etc/sysconfig/network-scripts/ifcfg-ib0
        sed -i "s@abcdefg@\$i@g" \$opn/etc/sysconfig/network-scripts/ifcfg-ib0
done
EOF

mkdir -p /opt/etc/
cat << EOF > /opt/etc/ifcfg-ib0
DEVICE=ib0
TYPE='InfiniBand'
BOOTPROTO=static
IPADDR=abcdefg
NETMASK=255.255.255.0
ONBOOT=yes
CONNECTED_MODE=yes
MTU=65520
EOF

sh ifcfg-ib.sh

wget $SOFT_SERV/abhpc.png -O /tftpboot/nbi_img/abhpc.png
rm -rf /tftpboot/nbi_img/drblwp.png

cat << EOF > /opt/etc/grub-efi.cfg
set default=abhpc-client
set timeout_style=menu
set timeout=7
set hidden_timeout_quiet=false
set graphic_bg=yes

function load_gfxterm {
  set gfxmode=auto
  insmod efi_gop
  insmod efi_uga
  insmod gfxterm
  terminal_output gfxterm
}

if [ x"\${graphic_bg}" = xyes ]; then
  if loadfont unicode; then
    load_gfxterm
  elif loadfont unicode.pf2; then
    load_gfxterm
  fi
fi
if background_image drblwp.png; then
  set color_normal=black/black
  set color_highlight=magenta/black
else
  set color_normal=cyan/blue
  set color_highlight=white/blue
fi

menuentry "Diskless ABHPC OS with CentOS 7.9 API" --id abhpc-client {
  echo "Enter ABHPC..."
  echo "Loading Linux kernel vmlinuz-pxe..."
  linux vmlinuz-pxe devfs=nomount drblthincli=off selinux=0 drbl_bootp=\$net_default_next_server nomodeset rd.driver.blacklist=nouveau nouveau.modeset=0
  echo "Loading initial ramdisk initrd-pxe.img..."
  initrd initrd-pxe.img
}

menuentry "Reboot" --id reboot {
  echo "System rebooting..."
  reboot
}

menuentry "Shutdown" --id shutdown {
  echo "System shutting down..."
  halt
}
EOF

cat << EOF > /opt/etc/pxelinux.cfg 
default menu.c32
timeout 5
prompt 0
noescape 1
MENU MARGIN 5
MENU BACKGROUND abhpc.png


say **********************************************
say Welcome to ABHPC.
say Advanced Computing Lab, CAEP.
say http://www.abhpc.com
say **********************************************

ALLOWOPTIONS 1

MENU TITLE ABHPC (http://www.abhpc.com)

label abhpc
  MENU DEFAULT
  MENU LABEL Diskless ABHPC OS with CentOS 7.9 API
  IPAPPEND 1
  kernel vmlinuz-pxe
  append initrd=initrd-pxe.img devfs=nomount drblthincli=off selinux=0 nomodeset blacklist=ast xdriver=vesa brokenmodules=ast
  TEXT HELP
  * ABHPC version: 2024b (C) 2024-2034, Xiaoyi Liu (xyliu@mechx.ac.cn)
  * Disclaimer: ABHPC is a HPC kernel over single-layer RDMA network
  ENDTEXT
EOF

\cp -Rf /opt/etc/pxelinux.cfg /tftpboot/nbi_img/pxelinux.cfg/default
\cp -Rf /opt/etc/grub-efi.cfg /tftpboot/nbi_img/grub-efi.cfg/grub.cfg

sed -i "s@DRBL@ABHPC@g" /etc/exports

# Generate ibpxe informarion
image=$(ls /tftpboot/nbi_img/initrd-pxe.*.img |awk -F "/" '{print $NF}')
ibmac=$(ip addr show ib0|grep infiniband|awk '{print $2}')
cat << EOF > /opt/etc/ibpxe.info
$image      $ibmac
EOF

drbl-cp-host ~/.ssh ~

if [[ -n "$LUSTRE_FS" && -n "$LUSTRE_MNT" ]]; then
    mkdir -p /tftpboot/node_root/$LUSTRE_MNT
fi