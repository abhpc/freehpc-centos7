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

yum install -y $SOFT_SERV/turbovnc-3.1.2-20240808.x86_64.rpm

# Download scow slurm adapter
mkdir -p /opt/scow-slurm-adapter/config
cd /opt/scow-slurm-adapter
wget $SOFT_SERV/scow-slurm-adapter
chmod +x scow-slurm-adapter

# Write scow slurm adapter config
cat << EOF > /opt/scow-slurm-adapter/config/config.yaml
# slurm database
mysql:
  host: 127.0.0.1
  port: 3306
  user: slurm
  dbname: slurm
  password: '$DBPASSWD'
  clustername: $CLUSNAME
  databaseencode: utf8

# service port
service:
  port: 8972

# slurm default Qos
slurm:
  defaultqos: normal
  slurmpath: $APP_DIR/slurm

# module profile path
modulepath:
  path: $APP_DIR/modules/init/profile.sh
EOF

# scow slurm adapter systemd service
cat << EOF > /etc/systemd/system/scow-adapter.service 
[Unit]
Description=SCOW SLURM Adapter Service
After=network.target

[Service]
StandardOutput=null
WorkingDirectory=/opt/scow-slurm-adapter/
ExecStart=/opt/scow-slurm-adapter/scow-slurm-adapter
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now scow-adapter.service

# Download and load docker images
cd $HOME
wget $SOFT_SERV/scow-images.tar.gz
tar -vxf scow-images.tar.gz
scowimg="fluentd.tar  mysql.tar  novnc.tar  redis.tar  scow.tar"
for i in $scowimg
do
    docker load -i $i
done
rm -rf *.tar *.tar.gz

# Revise auth.yml
cd $HOME
wget $SOFT_SERV/scow-abhpc.tgz
tar -vxf scow-abhpc.tgz
rm -rf scow-abhpc.tgz
cd scow-abhpc/config
sed -i "s/^\([[:space:]]*url:[[:space:]]*\).*/\1 ldap:\/\/$LDAP_SERV/" auth.yml
sed -i "s/^\([[:space:]]*bindDN:[[:space:]]*\).*/\1 cn=admin,$LDAP_BASE/" auth.yml
sed -i "s/^\([[:space:]]*bindPassword:[[:space:]]*\).*/\1 \"$LDAP_PASS\"/" auth.yml
sed -i "s/^\([[:space:]]*searchBase:[[:space:]]*\).*/\1 \"$LDAP_BASE\"/" auth.yml
sed -i "s/^\([[:space:]]*userBase:[[:space:]]*\).*/\1 \"$LDAP_BASE\"/" auth.yml
if [[ -n "$LUSTRE_FS" && -n "$LUSTRE_MNT" ]]; then
    sed -i "s|^\([[:space:]]*homeDir:[[:space:]]*\).*|\1 $LUSTRE_MNT/users/{{ userId }}|" auth.yml
else
    sed -i "s/^\([[:space:]]*homeDir:[[:space:]]*\).*/\1 \/home\/{{ userId }}/" auth.yml
fi

# Cluster configure
mstname=`hostname`
cat << EOF > clusters/$CLUSNAME.yml
displayName: ABHPC

loginNodes:
  - name: $mstname
    address: $MST_IP

adapterUrl: "$MST_IP:8972"

loginDesktop:
  enabled: true
  wms: 
    - name: Mate
      wm: mate
    - name: KDE
      wm: 1-kde-plasma-standard
  maxDesktops: 30
  desktopsDir: scow/desktops

turboVNCPath: /opt/TurboVNC
EOF

# Start SCOW
cd ..
service docker restart
./scow-cli compose up -d

# Add Group abhpc
cat << EOF > group.ldif
dn: cn=abhpc,dc=abhpc,dc=com
objectClass: top
objectClass: posixGroup
cn: abhpc
gidNumber: 5000
EOF
ldapadd -x -D "cn=admin,$LDAP_BASE" -w "$LDAP_PASS" -f group.ldif
rm -rf group.ldif