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

# Download glibc 2.28 and pre environment
cd $HOME
wget $SOFT_SERV/glibc-2.28.tar.gz
tar -vxf glibc-2.28.tar.gz
cd glibc-2.28/
sed -i "s@\"thread_db\"@\"thread_db\" \&\& \$name ne \"nss_test2\"@g" scripts/test-installation.pl

# Compile glibc 2.28
unset LD_LIBRARY_PATH
mkdir build
cd build
module load gcc/7.5.0 make/4.3
../configure --prefix=/usr --enable-obsolete-nsl
make -j 10
make install

# Continue building glibc
LD_PRELOAD=/lib64/libc-2.28.so sln /root/glibc-2.28/build/libc.so.6                 /lib64/libc.so.6
LD_PRELOAD=/lib64/libc-2.28.so sln /root/glibc-2.28/build/dlfcn/libdl.so.2          /lib64/libdl.so.2
LD_PRELOAD=/lib64/libc-2.28.so sln /root/glibc-2.28/build/nptl/libpthread.so.0      /lib64/libpthread.so.0
LD_PRELOAD=/lib64/libc-2.28.so sln /root/glibc-2.28/build/elf/ld-linux-x86-64.so.2  /usr/lib64/ld-linux-x86-64.so.2
make install

# Generate locales
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i zh_CN -f UTF-8 zh_CN.UTF-8

# Update munge.service file
cat << EOF > /usr/lib/systemd/system/munge.service
[Unit]
Description=MUNGE authentication service
Documentation=man:munged(8)
After=network.target
After=syslog.target
After=time-sync.target

[Service]
ExecStartPre=/bin/chown -Rf root:root /var/log/munge/ /run/munge /var/lib/munge /etc/munge/
Type=forking
ExecStart=/usr/sbin/munged
PIDFile=/var/run/munge/munged.pid
User=root
Group=root
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

# Change rc-local.service 
sed -i 's/^TimeoutSec=.*/TimeoutSec=120/' /usr/lib/systemd/system/rc-local.service

# Clean Files
cd $HOME
rm -rf glibc-2.28*
reboot