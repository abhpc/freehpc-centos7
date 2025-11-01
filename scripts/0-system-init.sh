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

# Configure yum and epel source
yum install -y $SOFT_SERV/wget-1.14-18.el7_6.1.x86_64.rpm
rm -rf /etc/yum.repos.d/*
cat << EOF > /etc/yum.repos.d/abhpc.repo
[base]
name=ABHPC CentOS-7  Base
baseurl=http://mx.yinhe596.cn:40888/mirrors/centos7/base
enabled=1
gpgcheck=0

[extras]
name=ABHPC CentOS-7  Extras 
baseurl=http://mx.yinhe596.cn:40888/mirrors/centos7/extras
enabled=1
gpgcheck=0

[updates]
name=ABHPC CentOS-7  Updates
baseurl=http://mx.yinhe596.cn:40888/mirrors/centos7/updates
enabled=1
gpgcheck=0

[epel]
name=ABHPC Extra Packages for Enterprise Linux 7
baseurl=http://mx.yinhe596.cn:40888/mirrors/centos7/epel
enabled=1
gpgcheck=0
EOF
yum clean all
yum makecache
yum update -y
yum install epel-release -y
rm -rf /etc/yum.repos.d/CentOS*.repo
rm -rf /etc/yum.repos.d/epel*.repo
yum groups mark convert
reboot