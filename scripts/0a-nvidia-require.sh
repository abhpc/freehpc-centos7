#! /bin/bash
#=======================================================================#
#                    ABHPC Basic Setup for CentOS 7.9                   #
#=======================================================================#

# Install required packages

# Load environment variables
. $HOME/env.conf

# check environment variable
if [ -z "$SOFT_SERV" ]; then
    echo "Error: The environmenal variable SOFT_SERV is empty."
    exit -1
fi

yum -y update
rm -rf /etc/yum.repos.d/epel*
yum -y groupinstall "Development Tools" "mate"
yum -y install kernel-devel
#yum -y install epel-release
yum -y install dkms

# Revise /etc/default/grub, generate new grub.cfg
sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ rd.driver.blacklist=nouveau nouveau.modeset=0"/' /etc/default/grub
sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# Disable nouveau
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
awk '!seen[$0]++' /etc/modprobe.d/blacklist.conf > /etc/modprobe.d/blacklist.conf.tmp
mv -f /etc/modprobe.d/blacklist.conf.tmp /etc/modprobe.d/blacklist.conf

# Update initramfs and reboot
mv -f /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r)-nouveau.img
dracut /boot/initramfs-$(uname -r).img $(uname -r)
reboot