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
SLM_NUM=$(printf "%03d" "$CLI_NUM")

cd $HOME
rpm -e VirtualGL
yum install -y $SOFT_SERV/VirtualGL-2.6.5.x86_64.rpm

# Master node VGL setting
rm -rf /etc/X11/xorg.conf
nvidia-xconfig -a --allow-empty-initial-configuration
sed -i '/Section "Screen"/,/EndSection/d' /etc/X11/xorg.conf

gpunum=$(lspci |grep -i nvidia|grep VGA|wc -l)
for (( i=0; i<$gpunum; i++ ))
do
cat << EOF >> /etc/X11/xorg.conf
Section "Screen"
    Identifier     "Screen$i"
    Device         "Device$i"
    Monitor        "Monitor$i"
    DefaultDepth   24
    Option         "UseDisplayDevice" "none"
    Option         "MultiGPU" "On"
    Option         "SLI" "off"
    Option         "BaseMosaic" "off"    
    Option         "Stereo" "0"
    Option         "HardDPMS" "false"
    SubSection     "Display"
        Virtual    1600 900
        Depth      24
    EndSubSection
EndSection
EOF
done
vglserver_config -config +s +f +t

mkdir -p $APP_DIR/bin
cat << EOF > $APP_DIR/bin/vgl.sh
init 3
nvidia-xconfig -a --allow-empty-initial-configuration

gpunum=\$(lspci |grep -i nvidia|grep VGA|wc -l)
for (( i=0; i<\$gpunum; i++ ))
do
cat << EOFIN >> /etc/X11/xorg.conf
Section "Screen"
    Identifier     "Screen\$i"
    Device         "Device\$i"
    Monitor        "Monitor\$i"
    DefaultDepth   24
    Option         "UseDisplayDevice" "none"
    Option         "MultiGPU" "On"
    Option         "SLI" "off"
    Option         "BaseMosaic" "off"    
    Option         "Stereo" "0"
    Option         "HardDPMS" "false"
    SubSection     "Display"
        Virtual    1600 900
        Depth      24
    EndSubSection
EndSection
EOFIN
done

vglserver_config -config +s +f +t
systemctl set-default graphical.target
reboot
EOF
chmod +x $APP_DIR/bin/vgl.sh

pdsh -t 1 -w ${CLI_PRE}[001-${SLM_NUM}] "$APP_DIR/bin/vgl.sh"

# Clean Files
cd $HOME
rm -rf VirtualGL-2.6.5.x86_64.rpm